import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../users/users_repository.dart';
import 'hr_actions.dart';
import 'hr_actions_repository.dart';
import 'payroll.dart';

// HR area: warnings, deductions, rewards and notes (user request 2026-11-07).

String hrKindLabel(AppLocalizations l10n, HrActionKind k) => switch (k) {
      HrActionKind.warning => l10n.hrKindWarning,
      HrActionKind.deduction => l10n.hrKindDeduction,
      HrActionKind.reward => l10n.hrKindReward,
      HrActionKind.note => l10n.hrKindNote,
    };

String warningLevelLabel(AppLocalizations l10n, WarningLevel l) => switch (l) {
      WarningLevel.verbal => l10n.warningVerbal,
      WarningLevel.first => l10n.warningFirst,
      WarningLevel.second => l10n.warningSecond,
      WarningLevel.last => l10n.warningLast,
    };

IconData hrKindIcon(HrActionKind k) => switch (k) {
      HrActionKind.warning => Icons.warning_amber_rounded,
      HrActionKind.deduction => Icons.remove_circle_outline,
      HrActionKind.reward => Icons.card_giftcard,
      HrActionKind.note => Icons.sticky_note_2_outlined,
    };

Color hrKindColor(BuildContext context, HrActionKind k) => switch (k) {
      HrActionKind.warning => Colors.orange.shade800,
      HrActionKind.deduction => Theme.of(context).colorScheme.error,
      HrActionKind.reward => Colors.green.shade700,
      HrActionKind.note => Theme.of(context).colorScheme.onSurfaceVariant,
    };

/// "300 SAR · 2 days" (empty when neither).
String hrPayLine(AppLocalizations l10n, HrAction a) => [
      if (a.amount != null && a.amount != 0) l10n.amountSar(formatAmount(a.amount!)),
      if (a.days != null && a.days != 0) l10n.daysOfSalary(formatAmount(a.days!)),
    ].join(' · ');

class HrActionTile extends ConsumerWidget {
  const HrActionTile({super.key, required this.action, this.showName = true});

  final HrAction action;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final a = action;
    final name = showName
        ? (ref.watch(usersProvider).value ?? const <AppUser>[]).where((u) => u.id == a.uid).firstOrNull?.name ?? l10n.deletedUser
        : null;
    final date = DateTime.tryParse(a.date);
    final color = a.cancelled ? Theme.of(context).disabledColor : hrKindColor(context, a.kind);
    return ListTile(
      leading: Icon(hrKindIcon(a.kind), color: color),
      title: Text(
        [?name, a.title].join(' · '),
        style: a.cancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Text([
        a.kind == HrActionKind.warning && a.level != null ? warningLevelLabel(l10n, a.level!) : hrKindLabel(l10n, a.kind),
        if (date != null) DateFormat.yMMMd(locale).format(date),
        if (a.kind.affectsPay) hrPayLine(l10n, a),
        if (a.kind.affectsPay && a.payMonth.isNotEmpty) l10n.payrollMonthOf(_monthLabel(locale, a.payMonth)),
        if (a.cancelled)
          l10n.hrActionCancelled
        else if (a.acceptedAt != null)
          l10n.hrAcceptedOn(DateFormat.yMMMd(locale).format(a.acceptedAt!))
        else if (a.sent)
          l10n.hrAwaitingAcceptance
        else
          l10n.hrInternalOnly,
      ].where((s) => s.isNotEmpty).join(' · ')),
      trailing: a.awaitingAcceptance
          ? Icon(Icons.hourglass_top, color: Colors.orange.shade800, semanticLabel: l10n.hrAwaitingAcceptance)
          : a.acceptedAt != null && !a.cancelled
              ? Icon(Icons.verified_outlined, color: Colors.green.shade700, semanticLabel: l10n.hrAccepted)
              : null,
      onTap: () => context.push('/hr/action/${a.id}'),
    );
  }
}

String _monthLabel(String locale, String month) {
  final d = DateTime.tryParse('$month-01');
  return d == null ? month : DateFormat.yMMMM(locale).format(d);
}

/// HR area tab: every warning / deduction / reward / note, newest first.
class HrActionsTab extends ConsumerStatefulWidget {
  const HrActionsTab({super.key});

  @override
  ConsumerState<HrActionsTab> createState() => _HrActionsTabState();
}

class _HrActionsTabState extends ConsumerState<HrActionsTab> {
  HrActionKind? _kind;
  bool _showCancelled = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEdit = canEditHrActions(ref.watch(currentUserProvider).value);
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final all = ref.watch(allHrActionsProvider);
    final list = [
      for (final a in all.value ?? const <HrAction>[])
        if ((_kind == null || a.kind == _kind) &&
            (_showCancelled || !a.cancelled) &&
            (_search.isEmpty || searchHas(users[a.uid]?.name ?? '', _search) || searchHas(a.title, _search)))
          a,
    ];
    int count(HrActionKind k) => (all.value ?? const <HrAction>[]).where((a) => a.kind == k && !a.cancelled).length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchEmployeeOrTitle,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.push('/hr/action/new'),
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: Text(l10n.all), selected: _kind == null, onSelected: (_) => setState(() => _kind = null)),
            for (final k in HrActionKind.values)
              ChoiceChip(
                avatar: Icon(hrKindIcon(k), size: 18),
                label: Text('${hrKindLabel(l10n, k)} (${count(k)})'),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = _kind == k ? null : k),
              ),
            FilterChip(
              label: Text(l10n.showCancelled),
              selected: _showCancelled,
              onSelected: (v) => setState(() => _showCancelled = v),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        if (all.isLoading && !all.hasValue) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (all.hasValue && list.isEmpty) ListTile(title: Text(l10n.noHrActions)),
        for (final a in list) HrActionTile(action: a),
      ],
    );
  }
}

/// Employee page section: the person's HR actions + "Add".
class PersonHrActionsSection extends ConsumerWidget {
  const PersonHrActionsSection({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    // Never on their own record (rules too).
    final canEdit = canEditHrActions(me) && me!.id != uid;
    final list = ref.watch(personHrActionsProvider(uid)).value ?? const <HrAction>[];
    final warnings = list.where((a) => a.kind == HrActionKind.warning && !a.cancelled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(children: [
            Expanded(child: Text(l10n.hrActionsTitle, style: theme.textTheme.titleMedium)),
            if (canEdit)
              TextButton.icon(
                onPressed: () => context.push('/hr/action/new?uid=$uid'),
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
              ),
          ]),
        ),
        if (warnings > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.warningsCount(warnings), style: TextStyle(color: Colors.orange.shade800)),
          ),
        if (list.isEmpty) ListTile(title: Text(l10n.noHrActions)),
        for (final a in list) HrActionTile(action: a, showName: false),
      ],
    );
  }
}

/// One HR action: details, documents, edit / cancel / delete.
class HrActionScreen extends ConsumerWidget {
  const HrActionScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.deleteHrActionTitle),
        content: Text(l10n.deleteHrActionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(hrActionsRepositoryProvider).delete(id);
    if (context.mounted) context.pop();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, HrAction a, String me) async {
    final l10n = AppLocalizations.of(context);
    if (a.cancelled) {
      await ref.read(hrActionsRepositoryProvider).setCancelled(id, false, '', me);
      return;
    }
    final note = await showTextInputDialog(context, title: l10n.cancelHrActionTitle, label: l10n.reasonOptional, confirmLabel: l10n.cancelHrAction);
    if (note == null) return;
    await ref.read(hrActionsRepositoryProvider).setCancelled(id, true, note, me);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final async = ref.watch(hrActionProvider(id));
    final a = async.value;
    final canEdit = canEditHrActions(me) && a != null && a.uid != me!.id;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: async.isLoading ? const CircularProgressIndicator() : Text(l10n.notFound)),
      );
    }
    final date = DateTime.tryParse(a.date);
    Widget row(String label, String value) => ListTile(
          dense: true,
          title: Text(label, style: theme.textTheme.labelMedium),
          subtitle: Text(value, style: theme.textTheme.bodyLarge),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(hrKindLabel(l10n, a.kind)),
        actions: [
          if (canEdit) ...[
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l10n.edit, onPressed: () => context.push('/hr/action/$id/edit')),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: () => _delete(context, ref)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: Icon(hrKindIcon(a.kind), color: hrKindColor(context, a.kind), size: 32),
            title: Text(a.title, style: theme.textTheme.titleLarge),
            subtitle: Text(users[a.uid]?.name ?? l10n.deletedUser),
            onTap: () => context.push('/hr/employee/${a.uid}'),
          ),
          if (a.cancelled)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.hrActionCancelled),
                subtitle: a.cancelNote.isEmpty ? null : Text(a.cancelNote),
              ),
            ),
          if (a.kind == HrActionKind.warning && a.level != null) row(l10n.warningLevel, warningLevelLabel(l10n, a.level!)),
          if (date != null) row(l10n.date, DateFormat.yMMMMd(locale).format(date)),
          if (a.kind.affectsPay) ...[
            if (hrPayLine(l10n, a).isNotEmpty) row(a.kind == HrActionKind.deduction ? l10n.deductionAmount : l10n.rewardAmount, hrPayLine(l10n, a)),
            row(l10n.payrollMonth, _monthLabel(locale, a.payMonth)),
          ],
          if (a.notes.isNotEmpty) row(l10n.notes, a.notes),
          row(
            l10n.hrEmployeeAcceptance,
            a.acceptedAt != null
                ? l10n.hrAcceptedOn(DateFormat.yMMMd(locale).add_jm().format(a.acceptedAt!))
                : a.sent
                    ? l10n.hrAwaitingAcceptance
                    : l10n.hrInternalOnly,
          ),
          if (a.createdBy.isNotEmpty)
            row(l10n.recordedBy, [users[a.createdBy]?.name ?? '', if (a.createdAt != null) DateFormat.yMMMd(locale).add_jm().format(a.createdAt!)].join(' · ')),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(context, ref, a, me.id),
                  icon: Icon(a.cancelled ? Icons.restore : Icons.block),
                  label: Text(a.cancelled ? l10n.restoreHrAction : l10n.cancelHrAction),
                ),
              ),
            ),
          const Divider(),
          AttachmentsSection(owner: (parent: AttachmentParent.hrActions, id: id), canAdd: canEdit, canDelete: canEdit),
        ],
      ),
    );
  }
}

/// New / edit form. [uid] preselects the employee for a new one.
class HrActionForm extends ConsumerStatefulWidget {
  const HrActionForm({super.key, this.id, this.uid});

  final String? id;
  final String? uid;

  @override
  ConsumerState<HrActionForm> createState() => _HrActionFormState();
}

class _HrActionFormState extends ConsumerState<HrActionForm> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  final _days = TextEditingController();
  String? _uid;
  HrActionKind _kind = HrActionKind.warning;
  WarningLevel? _level;
  DateTime _date = DateTime.now();
  String? _month;
  bool _loaded = false;
  bool _busy = false;
  bool _sendNote = false;
  HrAction? _original;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
  }

  @override
  void dispose() {
    for (final c in [_title, _notes, _amount, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(HrAction a) {
    _loaded = true;
    _original = a;
    _sendNote = a.sent;
    _uid = a.uid;
    _kind = a.kind;
    _level = a.level;
    _date = DateTime.tryParse(a.date) ?? DateTime.now();
    _month = a.kind.affectsPay ? a.payMonth : null;
    _title.text = a.title;
    _notes.text = a.notes;
    _amount.text = a.amount == null ? '' : formatAmount(a.amount!);
    _days.text = a.days == null ? '' : formatAmount(a.days!);
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save(String me) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    if (_uid == null) {
      error = l10n.chooseEmployee;
    } else if (_title.text.trim().isEmpty) {
      error = l10n.hrTitleRequired;
    } else if (_kind.affectsPay && (_num(_amount) ?? 0) <= 0 && (_num(_days) ?? 0) <= 0) {
      error = l10n.amountOrDaysRequired;
    }
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _busy = true);
    final day = DateFormat('yyyy-MM-dd').format(_date);
    final a = HrAction(
      id: widget.id ?? '',
      uid: _uid!,
      kind: _kind,
      level: _kind == HrActionKind.warning ? (_level ?? WarningLevel.verbal) : null,
      date: day,
      month: _month ?? day.substring(0, 7),
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      amount: _kind.affectsPay ? _num(_amount) : null,
      days: _kind.affectsPay ? _num(_days) : null,
      sent: _kind.alwaysSent || _sendNote,
    );
    // Accepted before and the content changed: the employee accepts again.
    final o = _original;
    final askAgain = o != null && o.acceptedAt != null && a.sent && !a.sameContentAs(o);
    try {
      final id = await ref.read(hrActionsRepositoryProvider).save(a, me, askAgain: askAgain);
      if (!mounted) return;
      // New: open it, where documents can be attached.
      if (widget.id == null) {
        context.pushReplacement('/hr/action/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    if (widget.id != null && !_loaded) {
      final a = ref.watch(hrActionProvider(widget.id!)).value;
      if (a == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      _load(a);
    }
    final people = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if ((u.active || u.id == _uid) && u.id != me?.id) u,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final all = ref.watch(allHrActionsProvider).value ?? const <HrAction>[];
    final suggested = _uid == null ? WarningLevel.verbal : nextWarningLevel(all.where((x) => x.id != widget.id).toList(), _uid!, _date);
    final level = _level ?? suggested;
    final now = DateTime.now();
    final months = [
      for (var i = -3; i <= 6; i++) DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
    ];
    final month = _month ?? DateFormat('yyyy-MM').format(_date);
    if (!months.contains(month)) months.insert(0, month);

    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? l10n.newHrAction : l10n.editHrAction)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownMenu<String>(
            initialSelection: _uid,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            label: Text(l10n.employee),
            enabled: widget.id == null,
            dropdownMenuEntries: [for (final u in people) DropdownMenuEntry(value: u.id, label: u.name)],
            onSelected: (v) => setState(() => _uid = v),
          ),
          const SizedBox(height: 16),
          SegmentedButton<HrActionKind>(
            segments: [
              for (final k in HrActionKind.values)
                ButtonSegment(value: k, icon: Icon(hrKindIcon(k)), label: Text(hrKindLabel(l10n, k))),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          if (_kind == HrActionKind.warning) ...[
            DropdownButtonFormField<WarningLevel>(
              initialValue: level,
              decoration: InputDecoration(
                labelText: l10n.warningLevel,
                helperText: _level == null ? l10n.warningLevelSuggested(warningActiveDays) : null,
              ),
              items: [
                for (final l in WarningLevel.values) DropdownMenuItem(value: l, child: Text(warningLevelLabel(l10n, l))),
              ],
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.date),
            subtitle: Text(DateFormat.yMMMMd(locale).format(_date)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 1),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l10n.hrActionTitleLabel, hintText: l10n.hrActionTitleHint),
          ),
          if (_kind.affectsPay) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.amountSarLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _days,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.daysOfSalaryLabel),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: month,
              decoration: InputDecoration(
                labelText: l10n.payrollMonth,
                helperText: payrollActive ? null : l10n.payrollMonthHelper,
              ),
              items: [for (final m in months) DropdownMenuItem(value: m, child: Text(_monthLabel(locale, m)))],
              onChanged: (v) => setState(() => _month = v),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(labelText: l10n.notes),
          ),
          if (_kind == HrActionKind.note)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.hrSendNote),
              subtitle: Text(l10n.hrSendNoteHint),
              value: _sendNote,
              onChanged: (v) => setState(() => _sendNote = v),
            ),
          const SizedBox(height: 8),
          if (_kind.alwaysSent || _sendNote)
            Card(
              color: theme.colorScheme.secondaryContainer,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: Text(_original?.acceptedAt != null ? l10n.hrWillAskAgain : l10n.hrWillBeSent),
              ),
            ),
          if (widget.id == null) ...[
            const SizedBox(height: 8),
            Text(l10n.hrAttachAfterSave, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || me == null ? null : () => _save(me.id),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
