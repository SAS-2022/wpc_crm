import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../hr/leave_widgets.dart';
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'absence.dart';
import 'absence_sheet.dart';

/// One reported absence (`/absence/:id`): who, which day, reason and text,
/// documents (the person adds them while it waits, e.g. a medical report),
/// the decision, and for HR / the GM: Reject (absence day), Accept as sick
/// leave (only with a document) or Accept as annual leave (shows what's left).
class AbsenceScreen extends ConsumerStatefulWidget {
  const AbsenceScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends ConsumerState<AbsenceScreen> {
  bool _busy = false;

  Future<void> _decide(Absence a, AppUser me, AppUser person, AbsenceLeave? countAs) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(countAs == null ? l10n.rejectAbsence : l10n.acceptAbsenceAs(absenceLeaveLabel(l10n, countAs))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(countAs == null ? l10n.rejectAbsenceHelp : l10n.acceptAbsenceHelp),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: countAs == null ? l10n.rejectReason : l10n.commentOptional),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            style: countAs == null ? FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error) : null,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(countAs == null ? l10n.reject : l10n.approve),
          ),
        ],
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await decideAbsence(
        absence: a,
        me: me,
        person: person,
        countAs: countAs,
        comment: text,
        types: ref.read(leaveTypesProvider).value ?? LeaveType.defaults,
        workDays: person.scheduleOr(ref.read(workHoursProvider).value ?? WorkHours.defaults).days,
        holidays: ref.read(holidaysProvider).value ?? const {},
        users: ref.read(usersProvider).value ?? const [],
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final async = ref.watch(absenceProvider(widget.id));
    final a = async.value;
    if (me == null || a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: async.isLoading ? const CircularProgressIndicator() : Text(l10n.absenceNotFound)),
      );
    }
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final person = users[a.uid];
    final mine = a.uid == me.id;
    final decides = decidesAbsences(me.role) && !mine;
    final owner = (parent: AttachmentParent.absences, id: a.id);
    final files = ref.watch(attachmentsProvider(owner)).value ?? const <Attachment>[];
    final color = absenceStatusColor(a, theme.colorScheme);

    // What's left of their annual leave in that year, for the decision.
    final year = int.parse(a.date.substring(0, 4));
    final types = ref.watch(leaveTypesProvider).value ?? LeaveType.defaults;
    final annual = types.where((t) => t.id == AbsenceLeave.annual.typeId).firstOrNull;
    LeaveBalance? annualLeft;
    if (decides && annual != null) {
      final record = ref.watch(leaveBalanceRecordProvider((a.uid, year))).value ?? LeaveBalanceRecord.empty;
      final requests = ref.watch(userLeaveRequestsProvider(a.uid)).value ?? const <LeaveRequest>[];
      annualLeft = leaveBalances(
        types: [annual],
        year: year,
        entitledOverride: record.entitled,
        adjustments: record.forBalance,
        requests: [for (final r in requests) r.use],
      )[annual.id];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.absenceTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: CircleAvatar(child: Text((person?.name ?? '?').characters.firstOrNull ?? '?')),
            title: Text(person?.name ?? ''),
            subtitle: Text([person?.role.label(l10n) ?? '', if (a.createdAt != null) DateFormat.MMMd(locale).add_jm().format(a.createdAt!)]
                .where((s) => s.isNotEmpty)
                .join(' · ')),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(DateFormat.yMMMMEEEEd(locale).format(DateTime.parse(a.date))),
          ),
          ListTile(
            leading: Icon(absenceReasonIcon(a.reason)),
            title: Text(absenceReasonLabel(l10n, a.reason)),
            subtitle: a.note.isEmpty ? null : SelectableText(a.note),
          ),
          ListTile(
            leading: Icon(Icons.circle, size: 14, color: color),
            title: Text(absenceStatusText(l10n, a), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            subtitle: a.pending
                ? null
                : Text([
                    users[a.decidedBy]?.name ?? '',
                    if (a.decidedAt != null) DateFormat.MMMd(locale).add_jm().format(a.decidedAt!),
                    if (a.comment.isNotEmpty) '“${a.comment}”',
                  ].where((s) => s.isNotEmpty).join(' · ')),
            trailing: a.leaveRequestId == null
                ? null
                : TextButton(onPressed: () => context.push('/leave/${a.leaveRequestId}'), child: Text(l10n.openRequest)),
          ),
          if (a.pending && a.reason == AbsenceReason.sick && files.isEmpty)
            ListTile(
              leading: Icon(Icons.attach_file, color: theme.colorScheme.error),
              title: Text(mine ? l10n.sickReportMissingMine : l10n.sickReportMissing, style: TextStyle(color: theme.colorScheme.error)),
            ),
          AttachmentsSection(
            owner: owner,
            canAdd: (mine && a.pending) || decides,
            canDelete: decides,
          ),
          // HR area: the person's leave balance, to decide what it counts as.
          if (me.role.canSeeHr)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LeaveBalanceTable(uid: a.uid, year: int.parse(a.date.substring(0, 4)), highlightTypeId: absenceLeaveTypeOf(a)),
            ),
          if (decides && a.pending && person != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(l10n.decideAbsence, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    // Sick leave needs the medical report (user decision 2026-10-22).
                    onPressed: _busy || files.isEmpty ? null : () => _decide(a, me, person, AbsenceLeave.sick),
                    icon: busyIcon(_busy, const Icon(Icons.sick_outlined)),
                    label: Text(l10n.acceptAbsenceAs(l10n.asSickLeave)),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _decide(a, me, person, AbsenceLeave.annual),
                    icon: busyIcon(_busy, const Icon(Icons.beach_access_outlined)),
                    label: Text(l10n.acceptAbsenceAs(l10n.asAnnualLeave)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: _busy ? null : () => _decide(a, me, person, null),
                    icon: busyIcon(_busy, const Icon(Icons.close)),
                    label: Text(l10n.rejectAbsence),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                [
                  if (files.isEmpty) l10n.sickNeedsDocument,
                  if (annualLeft != null) l10n.annualLeaveLeft(formatLeaveDays(annualLeft.remaining)),
                ].join('\n'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (mine && a.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await withdrawAbsence(a);
                        if (context.mounted) context.pop();
                      },
                icon: const Icon(Icons.undo),
                label: Text(l10n.absenceUndo),
              ),
            ),
        ],
      ),
    );
  }
}

/// Home, for HR and the GM: absences waiting for a decision.
class PendingAbsencesCard extends ConsumerWidget {
  const PendingAbsencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(pendingAbsencesProvider).value ?? const <Absence>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final day = DateFormat.MMMEd(Localizations.localeOf(context).toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.absencesWaiting(list.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final a in list.take(8))
              ListTile(
                leading: Icon(absenceReasonIcon(a.reason), color: Colors.orange.shade800),
                title: Text(users[a.uid]?.name ?? ''),
                subtitle: Text([day.format(DateTime.parse(a.date)), absenceReasonLabel(l10n, a.reason), a.note]
                    .where((s) => s.isNotEmpty)
                    .join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/absence/${a.id}'),
              ),
          ],
        ),
      ),
    );
  }
}

enum _AbsenceFilter { waiting, accepted, rejected, all }

/// HR area tab "Absences": every reported absence, waiting ones first by
/// default, so none is missed when a notification is (user request
/// 2026-10-22). Tap = the absence page with the decision buttons.
class HrAbsencesTab extends ConsumerStatefulWidget {
  const HrAbsencesTab({super.key});

  @override
  ConsumerState<HrAbsencesTab> createState() => _HrAbsencesTabState();
}

class _HrAbsencesTabState extends ConsumerState<HrAbsencesTab> {
  _AbsenceFilter _filter = _AbsenceFilter.waiting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = DateFormat.yMMMEd(Localizations.localeOf(context).toString());
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final all = ref.watch(allAbsencesProvider);
    final labels = {
      _AbsenceFilter.waiting: l10n.absenceWaiting,
      _AbsenceFilter.accepted: l10n.absenceAcceptedFilter,
      _AbsenceFilter.rejected: l10n.absenceRejectedFilter,
      _AbsenceFilter.all: l10n.allTime,
    };
    return all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
      data: (absences) {
        final waiting = absences.where((a) => a.pending).length;
        final list = [
          for (final a in absences)
            if (switch (_filter) {
              _AbsenceFilter.waiting => a.pending,
              _AbsenceFilter.accepted => a.status == AbsenceStatus.accepted,
              _AbsenceFilter.rejected => a.status == AbsenceStatus.rejected,
              _AbsenceFilter.all => true,
            })
              a,
        ];
        // Waiting ones oldest day first (decide in order); the rest latest first.
        if (_filter == _AbsenceFilter.waiting) list.sort((a, b) => a.date.compareTo(b.date));
        return ListView(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                for (final f in _AbsenceFilter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(f == _AbsenceFilter.waiting ? '${labels[f]!} ($waiting)' : labels[f]!),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
            ),
            if (list.isEmpty) ListTile(title: Text(l10n.noAbsences)),
            for (final a in list) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: absenceStatusColor(a, theme.colorScheme).withValues(alpha: 0.14),
                  child: Icon(absenceReasonIcon(a.reason), color: absenceStatusColor(a, theme.colorScheme)),
                ),
                title: Text(users[a.uid]?.name ?? ''),
                subtitle: Text(
                  [
                    [day.format(DateTime.parse(a.date)), absenceReasonLabel(l10n, a.reason)].join(' · '),
                    if (a.note.isNotEmpty) a.note,
                    absenceStatusText(l10n, a),
                  ].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/absence/${a.id}'),
              ),
              // Waiting absences: the person's leave balance right under it.
              if (a.pending)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 12),
                  child: LeaveBalanceTable(
                    uid: a.uid,
                    year: int.parse(a.date.substring(0, 4)),
                    highlightTypeId: absenceLeaveTypeOf(a),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The leave type an absence would most likely count as: sick leave for a
/// sick report, else annual leave (the two it can be accepted as).
String absenceLeaveTypeOf(Absence a) =>
    a.reason == AbsenceReason.sick ? AbsenceLeave.sick.typeId : AbsenceLeave.annual.typeId;
