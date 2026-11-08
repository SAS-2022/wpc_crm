import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'attendance_rules.dart' show defaultOvertimeMaxMin, formatMinutes;
import 'package:intl/intl.dart';

import 'attendance_repository.dart' show attendanceDay;
import 'overtime.dart';
import 'overtime_days.dart';

/// Attendance → Overtime permission (`/attendance/overtime`, user request
/// 2026-11-05): a department head switches overtime on / off for each of
/// their employees and sets the most a day. Off = time after the end of the
/// work day never counts, even when they stay ([canSetOvertimeFor]).
class OvertimePermissionScreen extends ConsumerStatefulWidget {
  const OvertimePermissionScreen({super.key});

  @override
  ConsumerState<OvertimePermissionScreen> createState() => _OvertimePermissionScreenState();
}

class _OvertimePermissionScreenState extends ConsumerState<OvertimePermissionScreen> {
  final _busy = <String>{};
  String _search = '';

  Future<void> _save(AppUser u, {required bool allowed, int? maxMin}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(u.id));
    try {
      await ref.read(usersRepositoryProvider).setOvertime(u.id, allowed: allowed, maxMin: maxMin);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final people = me == null
        ? const <AppUser>[]
        : ([
            for (final u in users)
              if (u.checksAttendance && canSetOvertimeFor(me, u, users)) u,
          ]..sort((a, b) => a.name.compareTo(b.name)));
    final shown = [
      for (final u in people)
        if (_search.isEmpty || searchHas(u.name, _search) || searchHas(u.role.label(l10n), _search)) u,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overtimePermission)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.overtimePermissionHelp, style: theme.textTheme.bodyMedium),
          ),
          if (me != null && people.isNotEmpty) _OvertimeDaysCard(me: me, people: people),
          if (people.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l10n.search, isDense: true),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
          if (people.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l10n.overtimePermissionNone, textAlign: TextAlign.center)),
          for (final u in shown)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(u.name),
                    subtitle: Text([
                      u.role.label(l10n),
                      if (u.overtimeAllowed) l10n.overtimeUpTo(formatMinutes(u.overtimeCapMin)),
                    ].join(' · ')),
                    value: u.overtimeAllowed,
                    onChanged: _busy.contains(u.id) ? null : (v) => _save(u, allowed: v, maxMin: u.overtimeMaxMin),
                  ),
                  if (u.overtimeAllowed)
                    ListTile(
                      dense: true,
                      title: Text(l10n.overtimeMax),
                      trailing: DropdownButton<int>(
                        value: u.overtimeCapMin,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final h in ({1, 2, 3, 4, 5, 6, 8, 10, 12, if (u.overtimeCapMin % 60 == 0) u.overtimeCapMin ~/ 60}.toList()..sort()))
                            DropdownMenuItem(value: h * 60, child: Text(l10n.hoursCount(h))),
                          if (u.overtimeCapMin % 60 != 0)
                            DropdownMenuItem(value: u.overtimeCapMin, child: Text('${u.overtimeCapMin} min')),
                        ],
                        onChanged: _busy.contains(u.id)
                            ? null
                            : (v) => _save(u, allowed: true, maxMin: v == defaultOvertimeMaxMin ? null : v),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Overtime on a chosen day (2026-11-08): who is allowed on which date
/// (from 30 days ago), with "Allow overtime on a day".
class _OvertimeDaysCard extends ConsumerWidget {
  const _OvertimeDaysCard({required this.me, required this.people});

  final AppUser me;

  /// The people [me] may set overtime for.
  final List<AppUser> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final byId = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final mine = {for (final u in people) u.id};
    final days = [
      for (final d in ref.watch(overtimeDaysProvider).value ?? const <OvertimeDay>[])
        if (mine.contains(d.uid)) d,
    ];
    final byDate = <String, List<OvertimeDay>>{};
    for (final d in days) {
      (byDate[d.date] ??= []).add(d);
    }
    final today = attendanceDay(DateTime.now());
    // Coming days first (soonest on top), then the past ones (latest first).
    final dates = byDate.keys.toList()
      ..sort((a, b) {
        final pa = a.compareTo(today) < 0, pb = b.compareTo(today) < 0;
        if (pa != pb) return pa ? 1 : -1;
        return pa ? b.compareTo(a) : a.compareTo(b);
      });
    final f = DateFormat.yMMMEd(locale);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.event_available, color: theme.colorScheme.primary),
              title: Text(l10n.overtimeDays, style: theme.textTheme.titleMedium),
              subtitle: Text(l10n.overtimeDaysHelp),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.allowOvertimeDay),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _OvertimeDayDialog(me: me, people: people),
                  ),
                ),
              ),
            ),
            for (final date in dates) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '${f.format(DateTime.parse(date))}${date == today ? ' · ${l10n.today}' : ''}',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: date.compareTo(today) < 0 ? theme.colorScheme.onSurfaceVariant : null),
                ),
              ),
              for (final d in byDate[date]!)
                ListTile(
                  dense: true,
                  title: Text(byId[d.uid]?.name ?? '?'),
                  subtitle: Text([
                    if (d.note.isNotEmpty) d.note,
                    l10n.allowedBy(byId[d.byId]?.name ?? ''),
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(l10n.removeOvertimeDayQ(byId[d.uid]?.name ?? '', f.format(DateTime.parse(d.date)))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.delete)),
                          ],
                        ),
                      );
                      if (ok == true) await ref.read(overtimeDaysRepositoryProvider).remove(d.id);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OvertimeDayDialog extends ConsumerStatefulWidget {
  const _OvertimeDayDialog({required this.me, required this.people});

  final AppUser me;
  final List<AppUser> people;

  @override
  ConsumerState<_OvertimeDayDialog> createState() => _OvertimeDayDialogState();
}

class _OvertimeDayDialogState extends ConsumerState<_OvertimeDayDialog> {
  DateTime? _date;
  final _picked = <String>{};
  final _note = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final shown = [
      for (final u in widget.people)
        if (_search.isEmpty || searchHas(u.name, _search) || _picked.contains(u.id)) u,
    ];
    return AlertDialog(
      title: Text(l10n.allowOvertimeDay),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_date == null ? l10n.pickDay : DateFormat.yMMMEd(locale).format(_date!)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  // Also a past day (allowed afterwards, it's worked out again).
                  firstDate: now.subtract(const Duration(days: 30)),
                  lastDate: now.add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: _note, decoration: InputDecoration(labelText: l10n.adjustNote, isDense: true)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l10n.search, isDense: true),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                children: [
                  for (final u in shown)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(u.id),
                      title: Text(u.name),
                      subtitle: Text(u.role.label(l10n)),
                      onChanged: (v) => setState(() => v == true ? _picked.add(u.id) : _picked.remove(u.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _date == null || _picked.isEmpty
              ? null
              : () async {
                  await ref.read(overtimeDaysRepositoryProvider).allow(
                        me: widget.me,
                        people: [for (final u in widget.people) if (_picked.contains(u.id)) u],
                        date: attendanceDay(_date!),
                        note: _note.text.trim(),
                      );
                  if (context.mounted) Navigator.pop(context);
                },
          child: Text(l10n.allowForCount(_picked.length)),
        ),
      ],
    );
  }
}
