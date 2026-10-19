import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';

// Same cases as functions/attendance.test.js.
void main() {
  DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 20, h, m);
  AttendanceEvent e(AttendanceEventType type, DateTime at) => AttendanceEvent(type, at);
  const inn = AttendanceEventType.in_, out = AttendanceEventType.out;
  DayResult run(List<AttendanceEvent> events, {DateTime? now, bool leaves = false, bool overtime = false}) => deriveDay(
        events,
        end: t(17),
        closeAll: t(23, 55),
        now: now ?? t(12),
        leavesSite: leaves,
        overtimeAllowed: overtime,
      );

  test('checked in at the first arrival', () {
    final d = run([e(inn, t(9, 40)), e(inn, t(10))]);
    expect(d.checkInAt, t(9, 40));
    expect(d.checkInSource, 'auto');
    expect(d.closed, isFalse);
  });

  test('leaving after 5 pm checks out; overtime counted only when allowed', () {
    final events = [e(inn, t(8)), e(out, t(18, 30))];
    final no = run(events, now: t(19));
    expect([no.checkOutAt, no.checkOutType, no.workedMin, no.countedMin, no.overtimeMin], [t(18, 30), 'left', 630, 540, 0]);
    final yes = run(events, now: t(19), overtime: true);
    expect([yes.countedMin, yes.overtimeMin], [630, 90]);
  });

  test('office: left at 2:40 and never back → checked out at 2:40 once the day ends', () {
    final events = [e(inn, t(8)), e(out, t(14, 40))];
    expect(run(events, now: t(16)).closed, isFalse);
    final d = run(events, now: t(17, 5));
    expect([d.checkOutAt, d.checkOutType, d.workedMin], [t(14, 40), 'leftEarly', 400]);
  });

  test('sales / drivers: out during the day, closed at 5 pm', () {
    final d = run([e(inn, t(8)), e(out, t(9))], now: t(17, 5), leaves: true);
    expect([d.checkOutAt, d.checkOutType, d.workedMin], [t(17), 'endOfDay', 540]);
  });

  test('manual check-out; arriving again doesn\'t reopen, a manual check-in does', () {
    final events = [e(inn, t(8)), e(AttendanceEventType.checkOut, t(15)), e(inn, t(15, 30))];
    expect(run(events, now: t(16)).checkOutType, 'manual');
    expect(run([...events, e(AttendanceEventType.checkIn, t(15, 31))], now: t(16)).closed, isFalse);
  });

  test('no exit by the evening: closed at the end of the work day (auto)', () {
    final d = run([e(inn, t(8))], now: t(23, 56));
    expect([d.checkOutAt, d.checkOutType], [t(17), 'auto']);
  });

  test('formats minutes', () => expect(formatMinutes(485), '8 h 05'));
}
