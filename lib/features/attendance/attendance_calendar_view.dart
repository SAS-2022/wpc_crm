import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../tracking/work_hours.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonLabel, absenceStatusText;
import 'attendance_calendar.dart';
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';

Color dayMarkColor(DayMark m, ColorScheme scheme) => switch (m) {
      DayMark.attended => Colors.green.shade600,
      DayMark.missed => scheme.error,
      DayMark.leave => Colors.blue.shade600,
      DayMark.absent => Colors.orange.shade700,
      DayMark.today => scheme.primary,
      DayMark.off || DayMark.future || DayMark.none => scheme.outlineVariant,
    };

/// The person's month of attendance: days checked in (green) and missed
/// (red), leave (blue), days off (grey); month totals; tap a day for its
/// times.
class MyAttendanceCalendar extends ConsumerStatefulWidget {
  const MyAttendanceCalendar({super.key, required this.me});

  final AppUser me;

  @override
  ConsumerState<MyAttendanceCalendar> createState() => _MyAttendanceCalendarState();
}

class _MyAttendanceCalendarState extends ConsumerState<MyAttendanceCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DayResult _result(AttendanceRecord r, WorkHours company) => r.best(widget.me, company);

  void _showDay(DateTime day, AttendanceRecord? r, DayMark mark, WorkHours hours, Absence? absence) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    final d = r == null ? null : _result(r, hours);
    final sites = {for (final s in ref.read(workSitesProvider).value ?? const <WorkSite>[]) s.id: s.name};
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat.yMMMMEEEEd(locale).format(day), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (d == null || !d.checkedIn)
                Text(switch (mark) {
                  DayMark.missed => l10n.dayMissed,
                  DayMark.leave => l10n.dayOnLeave,
                  DayMark.off => l10n.dayOff,
                  DayMark.absent when absence != null => l10n.dayReportedAbsent(absenceReasonLabel(l10n, absence.reason)),
                  _ => l10n.notCheckedIn,
                })
              else ...[
                Text(l10n.checkedInSince(time.format(d.checkInAt!), sites[d.siteId] ?? '')),
                if (d.checkInEventAt != null) Text(l10n.arrivedByGps(time.format(d.checkInEventAt!))),
                if (d.closed) Text('${l10n.checkedOutAt(time.format(d.checkOutAt!))} · ${checkOutTypeLabel(l10n, d.checkOutType)}'),
                if (d.countedMin != null) Text(l10n.workedTime(formatMinutes(d.countedMin!))),
                if ((d.lateMin ?? 0) > 0) Text(l10n.lateBy(formatMinutes(d.lateMin!))),
                if ((d.overtimeMin ?? 0) > 0) Text(l10n.overtimeTime(formatMinutes(d.overtimeMin!))),
                if (d.overtimeEndUnknown && d.lastSeenAt != null)
                  Text(l10n.overtimeEndUnknown(time.format(d.lastSeenAt!)), style: TextStyle(color: Colors.orange.shade800)),
                if ((d.afterHoursMin ?? 0) > 0) Text(l10n.stayedAfterTime(formatMinutes(d.afterHoursMin!))),
              ],
              if ((d == null || !d.checkedIn) && absence != null) ...[
                if (absence.note.isNotEmpty) Text(absence.note),
                Text(absenceStatusText(l10n, absence)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = widget.me;
    final hours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final records = ref.watch(myAttendanceProvider).value ?? const <String, AttendanceRecord>{};
    final holidays = ref.watch(holidaysProvider).value ?? const <String>{};
    final leaveDays = {
      for (final r in ref.watch(myLeaveRequestsProvider).value ?? const [])
        if (r.isLeave && r.status == LeaveStatus.approved && r.from != null && r.to != null) ...daysBetween(r.from!, r.to!),
    };
    final absences = ref.watch(myAbsencesProvider).value ?? const <String, Absence>{};
    final attended = {for (final MapEntry(:key, :value) in records.entries) if (_result(value, hours).checkedIn) key};
    // Attendance counts from their first check-in (or registration).
    final firstDay = attended.isEmpty ? null : DateTime.parse((attended.toList()..sort()).first);
    final since = [?firstDay, ?me.registeredAt].fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final now = DateTime.now();
    final marks = markMonth(
      month: _month,
      attended: attended,
      workDays: me.scheduleOr(hours).days,
      holidays: holidays,
      leaveDays: leaveDays,
      // Waiting for HR; rejected days count as missed, accepted ones are leave.
      absentDays: {for (final e in absences.entries) if (e.value.pending) e.key},
      since: since,
      today: now,
    );
    final key = DateFormat('yyyy-MM-dd');
    final monthRecords = [
      for (final d in marks.keys)
        if (records[key.format(d)] case final r?) _result(r, hours),
    ];
    final counted = monthRecords.fold<int>(0, (s, d) => s + (d.countedMin ?? 0));
    final overtime = monthRecords.fold<int>(0, (s, d) => s + (d.overtimeMin ?? 0));
    final afterHours = monthRecords.fold<int>(0, (s, d) => s + (d.afterHoursMin ?? 0));
    final lateDays = monthRecords.where((d) => (d.lateMin ?? 0) > 0).length;
    final attendedCount = marks.values.where((m) => m == DayMark.attended).length;
    final missedCount = marks.values.where((m) => m == DayMark.missed).length;
    final absentCount = marks.values.where((m) => m == DayMark.absent).length;

    // Weeks start on the locale's first day (Sunday in Arabic / Saudi use).
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final first = DateTime(_month.year, _month.month, 1);
    final lead = (first.weekday % 7 - firstWeekday) % 7;
    final names = DateFormat.E(locale).dateSymbols.NARROWWEEKDAYS; // Sunday first
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(DateFormat.yMMMM(locale).format(_month),
                      textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(names[(firstWeekday + i) % 7],
                        textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (final MapEntry(key: day, value: mark) in marks.entries)
                  _DayCell(
                    day: day.day,
                    mark: mark,
                    onTap: mark == DayMark.future || mark == DayMark.none
                        ? null
                        : () => _showDay(day, records[key.format(day)], mark, hours, absences[key.format(day)]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Legend(color: dayMarkColor(DayMark.attended, theme.colorScheme), label: l10n.daysAttended(attendedCount)),
                _Legend(color: dayMarkColor(DayMark.missed, theme.colorScheme), label: l10n.daysMissed(missedCount)),
                _Legend(color: dayMarkColor(DayMark.leave, theme.colorScheme), label: l10n.leaveLegend),
                if (absentCount > 0)
                  _Legend(color: dayMarkColor(DayMark.absent, theme.colorScheme), label: l10n.daysReportedAbsent(absentCount)),
                Text(l10n.monthHours(formatMinutes(counted)), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (overtime > 0) Text(l10n.overtimeTime(formatMinutes(overtime)), style: theme.textTheme.bodySmall),
                if (afterHours > 0) Text(l10n.stayedAfterTime(formatMinutes(afterHours)), style: theme.textTheme.bodySmall),
                if (lateDays > 0) Text(l10n.lateDays(lateDays), style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.mark, this.onTap});

  final int day;
  final DayMark mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = dayMarkColor(mark, scheme);
    final filled = mark == DayMark.attended || mark == DayMark.missed || mark == DayMark.leave || mark == DayMark.absent;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withValues(alpha: 0.85) : null,
          border: mark == DayMark.today ? Border.all(color: color, width: 2) : null,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            color: filled ? Colors.white : (mark == DayMark.future || mark == DayMark.none || mark == DayMark.off ? scheme.outline : null),
            fontWeight: filled || mark == DayMark.today ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
