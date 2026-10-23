import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';

// Same cases as functions/attendance.test.js.
void main() {
  DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 20, h, m);
  AttendanceEvent e(AttendanceEventType type, DateTime at) => AttendanceEvent(type, at);
  const inn = AttendanceEventType.in_, out = AttendanceEventType.out;
  DayResult run(List<AttendanceEvent> events,
          {DateTime? now, bool leaves = false, bool overtime = false, DateTime? start, Duration? grace}) => deriveDay(
        events,
        start: start,
        end: t(17),
        closeAll: t(23, 55),
        now: now ?? t(12),
        leavesSite: leaves,
        overtimeAllowed: overtime,
        awayGrace: grace,
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

  test('office: left at 2:40 and away over 30 min → checked out at 2:40', () {
    final events = [e(inn, t(8)), e(out, t(14, 40))];
    expect(run(events, now: t(15, 5)).closed, isFalse);
    final d = run(events, now: t(15, 10));
    expect([d.checkOutAt, d.checkOutType, d.workedMin], [t(14, 40), 'leftSite', 400]);
    expect(run(events, now: t(15, 20), grace: const Duration(minutes: 45)).closed, isFalse);
  });

  test('office: left at 4:45 → checked out at 4:45 once the day ends', () {
    final d = run([e(inn, t(8)), e(out, t(16, 45))], now: t(17, 5));
    expect([d.checkOutAt, d.checkOutType], [t(16, 45), 'leftEarly']);
  });

  test('office: out 20 min and back → stays in, the time counts', () {
    final events = [e(inn, t(8)), e(out, t(12)), e(inn, t(12, 20))];
    final d = run(events, now: t(16));
    expect([d.inside, d.lastExitAt, d.closed, d.awayMin], [true, null, false, 0]);
    expect(run([...events, e(out, t(17, 10))], now: t(18)).countedMin, 540);
  });

  test('office: out an hour and back → checked in again, the hour away not counted', () {
    final events = [e(inn, t(8)), e(out, t(12)), e(inn, t(13))];
    final d = run(events, now: t(16));
    expect([d.inside, d.closed, d.checkInAt, d.awayMin], [true, false, t(8), 60]);
    final o = run([...events, e(out, t(17, 10))], now: t(18));
    expect([o.checkOutType, o.countedMin, o.workedMin, o.afterHoursMin], ['left', 480, 490, 10]);
  });

  test('office: checked out for leaving, back only after 5 pm → stays out', () {
    final d = run([e(inn, t(8)), e(out, t(15)), e(inn, t(17, 20))], now: t(18));
    expect([d.checkOutAt, d.checkOutType], [t(15), 'leftSite']);
  });

  test('sales / drivers: out during the day, closed at 5 pm', () {
    final d = run([e(inn, t(8)), e(out, t(9))], now: t(17, 5), leaves: true);
    expect([d.checkOutAt, d.checkOutType, d.workedMin], [t(17), 'endOfDay', 540]);
  });

  test('manual check-out; arriving again doesn\'t reopen, a manual check-in does', () {
    final events = [e(inn, t(8)), e(AttendanceEventType.checkOut, t(15)), e(inn, t(15, 30))];
    expect(run(events, now: t(16)).checkOutType, 'manual');
    expect(run([...events, e(AttendanceEventType.checkIn, t(15, 31))], now: t(16)).closed, isFalse);
    final o = run([...events, e(AttendanceEventType.checkIn, t(15, 31)), e(AttendanceEventType.checkOut, t(16))], now: t(16));
    expect([o.awayMin, o.countedMin], [31, 449]);
  });

  test('no exit by the evening: closed at the end of the work day (auto)', () {
    final d = run([e(inn, t(8))], now: t(23, 56));
    expect([d.checkOutAt, d.checkOutType], [t(17), 'auto']);
  });

  test('formats minutes', () => expect(formatMinutes(485), '8 h 05'));

  test('lateness from the start of the work day; none on a day off', () {
    expect(run([e(inn, t(8, 22))], start: t(8)).lateMin, 22);
    expect(run([e(inn, t(8, 15).add(const Duration(seconds: 59)))], start: t(8)).lateMin, 0); // grace
    expect(run([e(inn, t(8, 16))], start: t(8)).lateMin, 16);
    expect(run([e(inn, t(7, 50))], start: t(8)).lateMin, 0);
    expect(run([e(inn, t(8, 22))]).lateMin, isNull);
    expect(run([], start: t(8)).lateMin, isNull);
  });

  test('without overtime the time stayed after the end is recorded, not counted', () {
    final events = [e(inn, t(8)), e(out, t(17, 45))];
    final no = run(events, now: t(19));
    expect([no.countedMin, no.overtimeMin, no.afterHoursMin], [540, 0, 45]);
    final yes = run(events, now: t(19), overtime: true);
    expect([yes.countedMin, yes.overtimeMin, yes.afterHoursMin], [585, 45, 0]);
  });

  test('geofence events checked against a GPS fix', () {
    // Site radius 100 m.
    bool enter(double d, double acc) => geofenceEventConfirmed(enter: true, distance: d, accuracy: acc, radius: 100);
    bool exit(double d, double acc) => geofenceEventConfirmed(enter: false, distance: d, accuracy: acc, radius: 100);
    expect(enter(80, 10), isTrue);
    expect(enter(170, 20), isTrue); // walking in, just outside
    expect(enter(2000, 15), isFalse); // false arrival from a rough network position
    expect(enter(2000, 400), isTrue); // fix too rough to tell
    expect(exit(300, 15), isTrue);
    expect(exit(40, 10), isFalse); // still inside
    expect(exit(90, 20), isTrue); // at the edge
  });

  test('HR correction replaces the phone\'s events', () {
    final phone = [e(inn, t(9, 30)), e(out, t(12)), e(inn, t(14))];
    final full = run(
      correctedEvents(phone, AttendanceCorrection(checkInAt: t(8), checkOutAt: t(17), siteId: 'hq')),
      now: t(18),
    );
    expect([full.checkInAt, full.checkInSource, full.siteId, full.checkOutAt, full.checkOutType, full.countedMin],
        [t(8), 'hr', 'hq', t(17), 'hr', 540]);
    final inOnly = run(correctedEvents(phone.take(2).toList(), AttendanceCorrection(checkInAt: t(8))), now: t(13));
    expect([inOnly.checkInAt, inOnly.closed, inOnly.checkOutType], [t(8), true, 'leftSite']);
    expect(correctedEvents([...phone, e(AttendanceEventType.hrOut, t(10))], null).length, 3);
  });
}
