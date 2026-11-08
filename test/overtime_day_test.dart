import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';

// Overtime on a chosen day (2026-11-08) — same cases as functions/attendance.test.js.
void main() {
  DateTime t(int d, int h, [int m = 0]) => DateTime(2026, 11, d, h, m);
  AttendanceEvent e(AttendanceEventType type, DateTime at) => AttendanceEvent(type, at, siteId: 's');

  test('day off: the whole stay is overtime, time out and back not counted', () {
    final events = [
      e(AttendanceEventType.in_, t(13, 8)),
      e(AttendanceEventType.out, t(13, 12)),
      e(AttendanceEventType.in_, t(13, 13)),
      e(AttendanceEventType.out, t(13, 19)),
    ];
    DayResult run(bool? off) => deriveDay(events,
        end: t(13, 17),
        closeAll: t(13, 23, 55),
        now: t(13, 23, 59),
        leavesSite: false,
        overtimeAllowed: false,
        overtimeDayOff: off);
    final d = run(true);
    expect(d.checkOutAt, t(13, 19));
    expect(d.workedMin, 600);
    expect(d.overtimeMin, 600);
    expect(d.countedMin, 600);
    expect(run(null).overtimeMin, 0);
  });

  test('work day: after the end counts without confirmation, up to the cap', () {
    final d = deriveDay([e(AttendanceEventType.in_, t(12, 8)), e(AttendanceEventType.out, t(12, 22))],
        start: t(12, 8),
        end: t(12, 17),
        closeAll: t(12, 23, 55),
        now: t(12, 23, 59),
        leavesSite: false,
        overtimeAllowed: false,
        overtimeMaxMin: 180,
        overtimeDayOff: false);
    expect(d.overtimeOn, isTrue);
    expect(d.overtimeMin, 180);
  });
}
