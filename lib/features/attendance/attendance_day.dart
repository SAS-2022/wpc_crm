import '../tracking/work_hours.dart';
import 'attendance_rules.dart';

/// Where someone stands on a day of the Attendance page (2026-10-21).
enum DayStatus {
  /// Checked in and at the site now.
  onSite,

  /// Checked in, then left the site (still counted until the day closes).
  away,

  /// No check-in.
  notIn,

  /// No check-in, reported "not coming to work" beforehand (2026-10-22),
  /// not (or not yet) accepted as leave.
  absent,

  /// No check-in, on approved leave.
  onLeave,

  /// The day is closed (checked out).
  checkedOut,
}

/// One person's day for the Attendance page: [workedMin] = counted minutes
/// (live while the day is open), [lateMin] = how late they checked in, or —
/// today, on a work day, not checked in yet — how long since their start
/// ([notInYet]); [scheduledMin] = the length of their work day (0 = day off).
typedef PersonDay = ({DayStatus status, int workedMin, int lateMin, bool notInYet, int scheduledMin});

/// [day]: midnight of the day shown; [schedule]: the person's work hours;
/// [now]: the phone clock (Saudi time on the team's phones).
PersonDay personDay(
  DayResult? d, {
  required WorkHours schedule,
  required bool overtimeAllowed,
  required DateTime day,
  required DateTime now,
  bool reportedAbsent = false,
  bool onLeave = false,
}) {
  final workDay = schedule.days.contains(day.weekday);
  final start = day.add(Duration(minutes: schedule.startMinute));
  final end = day.add(Duration(minutes: schedule.endMinute));
  final scheduled = workDay ? schedule.endMinute - schedule.startMinute : 0;
  if (d == null || !d.checkedIn) {
    if (onLeave || reportedAbsent) {
      return (
        status: onLeave ? DayStatus.onLeave : DayStatus.absent,
        workedMin: 0,
        lateMin: 0,
        notInYet: false,
        scheduledMin: scheduled,
      );
    }
    final today = day.year == now.year && day.month == now.month && day.day == now.day;
    final since = now.difference(start).inMinutes;
    final late = today && workDay && now.isBefore(end) && since > lateGraceMin ? since : 0;
    return (status: DayStatus.notIn, workedMin: 0, lateMin: late, notInYet: late > 0, scheduledMin: scheduled);
  }
  final late = d.lateMin ?? 0;
  if (d.closed) {
    return (
      status: DayStatus.checkedOut,
      workedMin: d.countedMin ?? 0,
      lateMin: late,
      notInYet: false,
      scheduledMin: scheduled,
    );
  }
  // Still open: up to now, or up to the end of the work day without overtime.
  final upTo = overtimeAllowed || now.isBefore(end) ? now : end;
  final worked = upTo.difference(d.checkInAt!).inMinutes - (d.awayMin ?? 0);
  return (
    status: d.inside ? DayStatus.onSite : DayStatus.away,
    workedMin: worked < 0 ? 0 : worked,
    lateMin: late,
    notInYet: false,
    scheduledMin: scheduled,
  );
}
