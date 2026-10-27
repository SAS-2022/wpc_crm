import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonLabel, absenceStatusText;
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'overtime.dart' show canApproveOvertime;
import 'overtime_widgets.dart' show showApproveOvertimeDialog;
import 'work_sites.dart';

/// Attendance page, tapping a person: their day (times, how it closed, a
/// reported absence, HR's correction) with "Correct this day" for HR / GM
/// (and the sales manager while testing) and "Open user" for admins.
Future<void> showAttendanceDaySheet(
  BuildContext context, {
  required AppUser person,
  required DateTime day,
  required AttendanceRecord? record,
  required DayResult? result,
  required Absence? absence,
  required bool canCorrect,
  required bool canOpenUser,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Consumer(builder: (sheet, ref, _) {
        final l10n = AppLocalizations.of(sheet);
        final locale = Localizations.localeOf(sheet).toString();
        final time = DateFormat.jm(locale);
        final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
        final sites = {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s.name};
        final c = record?.correction;
        final d = result;
        final me = ref.watch(currentUserProvider).value;
        final review = record?.review;
        // Overtime recorded (2026-10-25): approved by a manager, minutes adjustable.
        final hasOvertime = d != null && d.closed && (d.overtimeMin ?? 0) > 0 && record != null;
        final mayApprove = hasOvertime && me != null && canApproveOvertime(me, person, users.values.toList());
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(person.name, style: Theme.of(sheet).textTheme.titleLarge),
                Text(DateFormat.yMMMMEEEEd(locale).format(day)),
                const SizedBox(height: 12),
                if (d == null || !d.checkedIn)
                  Text(l10n.notCheckedIn)
                else ...[
                  Text(l10n.checkedInSince(time.format(d.checkInAt!), sites[d.siteId] ?? '')),
                  if (d.closed)
                    Text('${l10n.checkedOutAt(time.format(d.checkOutAt!))} · ${checkOutTypeLabel(l10n, d.checkOutType)}'),
                  if (d.countedMin != null) Text(l10n.workedTime(formatMinutes(d.countedMin!))),
                  if ((d.awayMin ?? 0) > 0) Text(l10n.awayTime(formatMinutes(d.awayMin!))),
                  if (d.overtimeEndUnknown && d.lastSeenAt != null && c == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.overtimeEndUnknown(time.format(d.lastSeenAt!)),
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                    ),
                    Text(l10n.overtimeEndUnknownHelp, style: Theme.of(sheet).textTheme.bodySmall),
                  ],
                ],
                if (c != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [l10n.correctedBy(users[c.byId]?.name ?? ''), if (c.note.isNotEmpty) '“${c.note}”'].join(' · '),
                    style: TextStyle(color: Theme.of(sheet).colorScheme.primary),
                  ),
                ],
                if (hasOvertime) ...[
                  const SizedBox(height: 8),
                  Text(
                    review == null
                        ? l10n.overtimeWaiting(formatMinutes(d.overtimeMin!))
                        : review.rejected
                        ? l10n.overtimeRejectedBy(users[review.byId]?.name ?? '')
                        : l10n.overtimeApprovedBy(formatMinutes(review.minutes), users[review.byId]?.name ?? ''),
                    style: TextStyle(
                      color: review == null
                          ? Colors.orange.shade800
                          : review.rejected
                          ? Theme.of(sheet).colorScheme.error
                          : Colors.green.shade700,
                    ),
                  ),
                  if (review != null && review.note.isNotEmpty) Text('“${review.note}”'),
                ],
                if (absence != null) ...[
                  const SizedBox(height: 8),
                  Text('${absenceReasonLabel(l10n, absence.reason)} · ${absenceStatusText(l10n, absence)}'),
                  if (absence.note.isNotEmpty) Text(absence.note),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (mayApprove)
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          await showApproveOvertimeDialog(context, me: me, person: person, record: record, result: d);
                        },
                        icon: const Icon(Icons.more_time),
                        label: Text(l10n.approveOvertime),
                      ),
                    if (canCorrect)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          await _correct(context, person, day, record, result);
                        },
                        icon: const Icon(Icons.edit_calendar),
                        label: Text(l10n.correctDay),
                      ),
                    if (canCorrect && c != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          await removeAttendanceCorrection(person.id, attendanceDay(day));
                        },
                        icon: const Icon(Icons.undo),
                        label: Text(l10n.removeCorrection),
                      ),
                    if (absence != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheet);
                          context.push('/absence/${absence.id}');
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: Text(l10n.openAbsence),
                      ),
                    if (canOpenUser)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheet);
                          context.push('/users/${person.id}');
                        },
                        icon: const Icon(Icons.person_outline),
                        label: Text(l10n.openUser),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );

/// HR's dialog: check-in time, optional check-out time, site and a note.
Future<void> _correct(BuildContext context, AppUser person, DateTime day, AttendanceRecord? record, DayResult? result) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CorrectionDialog(person: person, day: day, record: record, result: result),
    );

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog({required this.person, required this.day, required this.record, required this.result});

  final AppUser person;
  final DateTime day;
  final AttendanceRecord? record;
  final DayResult? result;

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  final _note = TextEditingController();
  late TimeOfDay _in;
  TimeOfDay? _out;
  String? _site;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final hours = widget.person.scheduleOr(ref.read(workHoursProvider).value ?? WorkHours.defaults);
    final c = widget.record?.correction;
    final d = widget.result;
    TimeOfDay of(DateTime t) => TimeOfDay.fromDateTime(t);
    TimeOfDay minutes(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
    _in = c != null ? of(c.checkInAt) : d?.checkInAt != null ? of(d!.checkInAt!) : minutes(hours.startMinute);
    _out = c != null
        ? (c.checkOutAt == null ? null : of(c.checkOutAt!))
        : d?.checkOutAt != null
            ? of(d!.checkOutAt!)
            : minutes(hours.endMinute);
    _site = c?.siteId ?? d?.siteId ?? widget.person.workSiteIds.firstOrNull;
    _note.text = c?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(widget.day.year, widget.day.month, widget.day.day, t.hour, t.minute);

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = _note.text.trim();
    if (note.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.correctionNoteNeeded)));
      return;
    }
    if (_out != null && !_at(_out!).isAfter(_at(_in))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.endAfterStart)));
      return;
    }
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await correctAttendance(
        widget.person.id,
        attendanceDay(widget.day),
        AttendanceCorrection(checkInAt: _at(_in), checkOutAt: _out == null ? null : _at(_out!), siteId: _site, note: note),
        me.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sites = [
      for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[])
        if (widget.person.workSiteIds.contains(s.id) || s.id == _site) s,
    ];
    Future<TimeOfDay?> pick(TimeOfDay initial) => showTimePicker(context: context, initialTime: initial);
    return AlertDialog(
      title: Text(l10n.correctDayOf(widget.person.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.correctDayHelp, style: Theme.of(context).textTheme.bodySmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.login),
              title: Text(l10n.checkIn),
              trailing: Text(_in.format(context)),
              onTap: () async {
                final t = await pick(_in);
                if (t != null) setState(() => _in = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: Text(l10n.checkOut),
              subtitle: _out == null ? Text(l10n.checkOutFromPhone) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_out != null) Text(_out!.format(context)),
                  IconButton(
                    tooltip: _out == null ? l10n.add : l10n.clear,
                    icon: Icon(_out == null ? Icons.add : Icons.close),
                    onPressed: () => setState(() => _out = _out == null ? const TimeOfDay(hour: 17, minute: 0) : null),
                  ),
                ],
              ),
              onTap: () async {
                final t = await pick(_out ?? const TimeOfDay(hour: 17, minute: 0));
                if (t != null) setState(() => _out = t);
              },
            ),
            if (sites.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _site,
                decoration: InputDecoration(labelText: l10n.workSites),
                items: [for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setState(() => _site = v),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.correctionNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
      ],
    );
  }
}
