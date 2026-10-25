import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'overtime.dart';
import 'work_sites.dart';

/// End of [me]'s work day on [now]'s date.
DateTime _endOf(AppUser me, WorkHours company, DateTime now) =>
    DateTime(now.year, now.month, now.day).add(Duration(minutes: me.scheduleOr(company).endMinute));

/// Starts overtime with feedback (not at the site → message).
Future<void> _start(BuildContext context, WidgetRef ref, AppUser me) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final company = ref.read(workHoursProvider).value ?? WorkHours.defaults;
  final time = DateFormat.jm(Localizations.localeOf(context).toString()).format(_endOf(me, company, DateTime.now()));
  final sites = ref.read(workSitesProvider).value ?? const <WorkSite>[];
  final result = await saving(() => startOvertime(me, sites));
  messenger.showSnackBar(SnackBar(
    content: Text(result == StartOvertimeResult.started ? l10n.overtimeStartedToast(time) : l10n.overtimeNotAtSite),
  ));
}

/// Overtime part of the Home attendance card (2026-10-25): the "Start
/// overtime?" question, overtime running (site or driving), or the day's
/// overtime and whether a manager approved it.
class OvertimeSection extends ConsumerStatefulWidget {
  const OvertimeSection({super.key, required this.me, required this.record, required this.day});

  final AppUser me;
  final AttendanceRecord? record;
  final DayResult? day;

  @override
  ConsumerState<OvertimeSection> createState() => _OvertimeSectionState();
}

class _OvertimeSectionState extends ConsumerState<OvertimeSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = widget.me;
    final day = widget.day;
    if (!me.overtimeAllowed || day == null || !day.checkedIn) return const SizedBox.shrink();
    final now = DateTime.now();
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final end = _endOf(me, company, now);
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    final drive = widget.record?.drive;

    if (overtimeQuestionPending(me, day, me.scheduleOr(company), now)) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.more_time, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.overtimeQuestion(time.format(end)), style: theme.textTheme.titleSmall)),
            ]),
            const SizedBox(height: 4),
            Text(l10n.overtimeQuestionHelp(time.format(end)), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(onPressed: _busy ? null : () => _run(() => declineOvertime(me)), child: Text(l10n.notToday)),
                FilledButton.icon(
                  icon: const Icon(Icons.more_time),
                  label: BusyLabel(busy: _busy, child: Text(l10n.startOvertime)),
                  onPressed: _busy ? null : () => _run(() => _start(context, ref, me)),
                ),
              ],
            ),
          ],
        ),
      );
    }
    // "Not today" by mistake: still possible while at the site.
    if (overtimeQuestionPending(me, day, me.scheduleOr(company), now, afterDecline: true)) {
      return ListTile(
        dense: true,
        leading: Icon(Icons.more_time, color: theme.colorScheme.outline),
        title: Text(l10n.overtimeDeclinedText),
        trailing: TextButton(
          onPressed: _busy ? null : () => _run(() => _start(context, ref, me)),
          child: BusyLabel(busy: _busy, child: Text(l10n.startOvertime)),
        ),
      );
    }
    final String? text;
    if (!day.closed && drive != null && drive.running) {
      text = l10n.driveOvertimeRunning(time.format(drive.startAt));
    } else if (!day.closed && day.overtimeOn) {
      final cap = end.add(Duration(minutes: me.overtimeCapMin));
      final so = (now.isBefore(cap) ? now : cap).difference(end).inMinutes;
      text = l10n.overtimeSince(time.format(end), formatMinutes(so < 0 ? 0 : so));
    } else if (day.closed && (day.overtimeMin ?? 0) > 0) {
      final review = widget.record?.review;
      text = review != null
          ? l10n.overtimeApprovedText(formatMinutes(review.minutes))
          : l10n.overtimeWaiting(formatMinutes(day.overtimeMin!));
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      leading: Icon(Icons.more_time, color: Colors.green.shade700),
      title: Text(text),
    );
  }
}

/// Pops up "Start overtime?" when the app opens or comes back while the
/// question is open (and once while it stays open in front), and "Overtime
/// started" once for a driver whose driving overtime began (2026-10-25,
/// user request: a pop-up when it starts and when the app opens). Phones only.
class OvertimePromptGate extends ConsumerStatefulWidget {
  const OvertimePromptGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OvertimePromptGate> createState() => _OvertimePromptGateState();
}

class _OvertimePromptGateState extends ConsumerState<OvertimePromptGate> with WidgetsBindingObserver {
  Timer? _timer;
  bool _showing = false;

  /// Asked since the app last came to the front.
  bool _askedThisTime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The question opens 10 min after the end, maybe with the app in front.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _askedThisTime = false;
      _check();
    }
  }

  Future<void> _check() async {
    if (kIsWeb || _showing || !mounted) return;
    // Only in front: a dialog opened in the background (locked phone, push
    // just arrived) went unseen (found 2026-10-25). Resuming checks again.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final me = ref.read(currentUserProvider).value;
    final record = ref.read(myAttendanceTodayProvider).value;
    if (me == null || record == null || !me.overtimeAllowed) return;
    final company = ref.read(workHoursProvider).value ?? WorkHours.defaults;
    final day = record.best(me, company);
    final now = DateTime.now();
    if (!_askedThisTime && overtimeQuestionPending(me, day, me.scheduleOr(company), now)) {
      _askedThisTime = true;
      await _show(() => _askDialog(me, company));
      return;
    }
    final drive = record.drive;
    if (drive != null && drive.running && !day.closed) {
      final key = 'overtimeDriveShown_${record.date}_${drive.startAt.millisecondsSinceEpoch}';
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(key) == true || _showing || !mounted) return;
        await _show(() => _driveDialog(drive));
        // Remembered once seen and closed.
        await prefs.setBool(key, true);
      } catch (_) {}
    }
  }

  Future<void> _show(Future<void> Function() dialog) async {
    _showing = true;
    try {
      await dialog();
    } finally {
      _showing = false;
    }
  }

  Future<void> _askDialog(AppUser me, WorkHours company) async {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat.jm(Localizations.localeOf(context).toString()).format(_endOf(me, company, DateTime.now()));
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: Icon(Icons.more_time, color: Colors.orange.shade800, size: 40),
        title: Text(l10n.overtimeQuestion(time)),
        content: Text(l10n.overtimeQuestionHelp(time)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, 'no'), child: Text(l10n.notToday)),
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.later)),
          FilledButton(onPressed: () => Navigator.pop(dialog, 'start'), child: Text(l10n.startOvertime)),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'start') await _start(context, ref, me);
    if (choice == 'no') await saving(() => declineOvertime(me));
  }

  Future<void> _driveDialog(DriveOvertime drive) {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat.jm(Localizations.localeOf(context).toString()).format(drive.startAt);
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: Icon(Icons.more_time, color: Colors.green.shade700, size: 40),
        title: Text(l10n.driveOvertimeTitle),
        content: Text(l10n.driveOvertimeRunning(time)),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.close))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A new answer from the server (e.g. the day's record arriving) may open the question.
    ref.listen(myAttendanceTodayProvider, (_, _) => _check());
    return widget.child;
  }
}

/// A manager approves [person]'s overtime on [record]'s day, possibly
/// changing the minutes (15-minute steps).
Future<void> showApproveOvertimeDialog(
  BuildContext context, {
  required AppUser me,
  required AppUser person,
  required AttendanceRecord record,
  required DayResult result,
}) async {
  final l10n = AppLocalizations.of(context);
  final time = DateFormat.jm(Localizations.localeOf(context).toString());
  final recorded = result.overtimeMin ?? 0;
  var minutes = record.review?.minutes ?? recorded;
  final note = TextEditingController(text: record.review?.note ?? '');
  final end = result.checkOutAt;
  final from = end?.subtract(Duration(minutes: recorded));
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text('${l10n.approveOvertime} · ${person.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(DateTime.parse(record.date))),
            if (from != null && end != null)
              Text(l10n.overtimeRecorded(formatMinutes(recorded), time.format(from), time.format(end))),
            const SizedBox(height: 12),
            Text(l10n.overtimeApprovedMinutes, style: Theme.of(dialog).textTheme.labelLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed: minutes <= 0 ? null : () => setState(() => minutes = (minutes - 15).clamp(0, 720)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(formatMinutes(minutes), style: Theme.of(dialog).textTheme.headlineSmall),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: minutes >= 720 ? null : () => setState(() => minutes = (minutes + 15).clamp(0, 720)),
                ),
              ],
            ),
            TextField(controller: note, decoration: InputDecoration(labelText: l10n.noteOptional)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.approveOvertime)),
        ],
      ),
    ),
  );
  if (ok == true) {
    await approveOvertime(person.id, record.date, minutes: minutes, byId: me.id, note: note.text.trim());
  }
  note.dispose();
}

/// Home (managers, HR area): days whose overtime waits for approval by the
/// viewer; tap = approve (with the minutes adjustable).
class OvertimeApprovalsCard extends ConsumerWidget {
  const OvertimeApprovalsCard({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final byId = {for (final u in users) u.id: u};
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final waiting = [
      for (final r in ref.watch(overtimeToApproveProvider).value ?? const <AttendanceRecord>[])
        if (byId[r.uid] != null && canApproveOvertime(me, byId[r.uid]!, users)) r,
    ];
    if (waiting.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.more_time, color: Colors.orange.shade800),
            title: Text(l10n.overtimeToApprove(waiting.length), style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final r in waiting)
            Builder(builder: (context) {
              final person = byId[r.uid]!;
              final result = r.best(person, company);
              return ListTile(
                dense: true,
                title: Text(person.name),
                subtitle: Text([
                  DateFormat.MMMEd(locale).format(DateTime.parse(r.date)),
                  l10n.overtimeTime(formatMinutes(result.overtimeMin ?? 0)),
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showApproveOvertimeDialog(context, me: me, person: person, record: r, result: result),
              );
            }),
        ],
      ),
    );
  }
}
