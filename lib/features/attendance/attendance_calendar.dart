import 'package:intl/intl.dart';

// The person's own attendance calendar (user request 2026-10-19): which days
// they checked in and which work days they missed.

enum DayMark {
  /// Checked in that day.
  attended,

  /// A work day in the past without a check-in.
  missed,

  /// Approved leave.
  leave,

  /// Not a work day (weekend) or a public holiday.
  off,

  /// Today, not checked in (yet).
  today,

  /// Later than today.
  future,

  /// Before attendance started for them (no check-in yet back then).
  none,
}

final _key = DateFormat('yyyy-MM-dd');

/// Marks every day of [month]'s month. [since]: the first day attendance
/// counts for the person (their first check-in, or when they registered);
/// work days before it aren't "missed". [workDays]: weekdays (Monday = 1).
Map<DateTime, DayMark> markMonth({
  required DateTime month,
  required Set<String> attended,
  required Set<int> workDays,
  required Set<String> holidays,
  required Set<String> leaveDays,
  required DateTime? since,
  required DateTime today,
}) {
  final todayDay = DateTime(today.year, today.month, today.day);
  final start = since == null ? null : DateTime(since.year, since.month, since.day);
  final out = <DateTime, DayMark>{};
  for (var d = DateTime(month.year, month.month, 1); d.month == month.month; d = DateTime(d.year, d.month, d.day + 1)) {
    final key = _key.format(d);
    out[d] = attended.contains(key)
        ? DayMark.attended
        : d.isAfter(todayDay)
            ? DayMark.future
            : leaveDays.contains(key)
                ? DayMark.leave
                : !workDays.contains(d.weekday) || holidays.contains(key)
                    ? DayMark.off
                    : d == todayDay
                        ? DayMark.today
                        : start == null || d.isBefore(start)
                            ? DayMark.none
                            : DayMark.missed;
  }
  return out;
}

/// 'yyyy-MM-dd' of every day from [from] to [to] (inclusive).
Set<String> daysBetween(String from, String to) {
  final a = DateTime.tryParse(from), b = DateTime.tryParse(to);
  if (a == null || b == null || b.isBefore(a)) return const {};
  return {
    for (var d = a; !d.isAfter(b); d = DateTime(d.year, d.month, d.day + 1)) _key.format(d),
  };
}
