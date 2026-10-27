import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';

// Same cases as functions/attendance.test.js.
void main() {
  DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 20, h, m);
  AttendanceEvent e(AttendanceEventType type, DateTime at) => AttendanceEvent(type, at);
  const inn = AttendanceEventType.in_, out = AttendanceEventType.out;
  DayResult run(
    List<AttendanceEvent> events, {
    DateTime? now,
    bool leaves = false,
    bool overtime = false,
    DateTime? start,
    Duration? grace,
    int cap = defaultOvertimeMaxMin,
    DateTime? seen,
    bool confirm = true,
    DriveOvertime? drive,
  }) => deriveDay(
    // With overtime the tests confirm it at 17:01 ("Start overtime", 2026-10-25) unless confirm: false.
    overtime && confirm ? [...events, e(AttendanceEventType.otStart, t(17, 1))] : events,
    drive: drive,
    start: start,
    end: t(17),
    closeAll: t(23, 55),
    now: now ?? t(12),
    leavesSite: leaves,
    overtimeAllowed: overtime,
    overtimeMaxMin: cap,
    lastSeenAt: seen,
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
    expect(
      [no.checkOutAt, no.checkOutType, no.workedMin, no.countedMin, no.overtimeMin],
      [t(18, 30), 'left', 630, 540, 0],
    );
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

  test('sales / drivers: away at 5 pm, a later exit keeps the 5 pm check-out', () {
    // Worker Number Two, 26 Oct: left at 15:27, two exits at 18:18 had moved it to 18:18.
    final d = run([e(inn, t(8, 46)), e(out, t(15, 27)), e(out, t(18, 18))],
        now: t(18, 20), leaves: true, overtime: true, confirm: false);
    expect([d.checkOutAt, d.checkOutType, d.afterHoursMin], [t(17), 'endOfDay', 0]);
  });

  test('manual check-out; arriving again doesn\'t reopen, a manual check-in does', () {
    final events = [e(inn, t(8)), e(AttendanceEventType.checkOut, t(15)), e(inn, t(15, 30))];
    expect(run(events, now: t(16)).checkOutType, 'manual');
    expect(run([...events, e(AttendanceEventType.checkIn, t(15, 31))], now: t(16)).closed, isFalse);
    final o = run([
      ...events,
      e(AttendanceEventType.checkIn, t(15, 31)),
      e(AttendanceEventType.checkOut, t(16)),
    ], now: t(16));
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
    expect(
      [full.checkInAt, full.checkInSource, full.siteId, full.checkOutAt, full.checkOutType, full.countedMin],
      [t(8), 'hr', 'hq', t(17), 'hr', 540],
    );
    final inOnly = run(correctedEvents(phone.take(2).toList(), AttendanceCorrection(checkInAt: t(8))), now: t(13));
    expect([inOnly.checkInAt, inOnly.closed, inOnly.checkOutType], [t(8), true, 'leftSite']);
    expect(correctedEvents([...phone, e(AttendanceEventType.hrOut, t(10))], null).length, 3);
  });

  test('overtime is capped at 3 hours unless the person has a higher cap', () {
    final events = [e(inn, t(8)), e(out, t(21, 30))];
    final d = run(events, now: t(22), overtime: true);
    expect([d.workedMin, d.overtimeMin, d.afterHoursMin, d.countedMin], [810, 180, 90, 720]);
    final more = run(events, now: t(22), overtime: true, cap: 300);
    expect([more.overtimeMin, more.afterHoursMin, more.countedMin], [270, 0, 810]);
  });

  test('no exit seen, overtime allowed: closed when last seen at the site, within the cap', () {
    final events = [e(inn, t(8))];
    final seen = run(events, now: t(23, 55), overtime: true, seen: t(19, 10));
    expect([seen.checkOutAt, seen.checkOutType, seen.overtimeMin], [t(19, 10), 'auto', 130]);
    final late = run(events, now: t(23, 55), overtime: true, seen: t(23));
    expect([late.checkOutAt, late.overtimeMin], [t(20), 180]);
    final quiet = run([...events, e(inn, t(11, 20))], now: t(23, 55), overtime: true, seen: t(12, 10));
    expect([quiet.checkOutAt, quiet.overtimeMin], [t(17), 0]);
    final no = run(events, now: t(23, 55), seen: t(19, 10));
    expect([no.checkOutAt, no.overtimeMin], [t(17), 0]);
    final arrival = run([...events, e(inn, t(18, 30))], now: t(23, 55), overtime: true);
    expect([arrival.checkOutAt, arrival.overtimeMin], [t(18, 30), 90]);
  });

  // Site checks (2026-10-25), same as attendance.test.js.
  const seenT = AttendanceEventType.seen;
  test('silent phone, no site check answered: closed at the end, overtime unconfirmed', () {
    final d = run([e(inn, t(6, 56))], overtime: true, now: t(23, 55), seen: t(8, 4));
    expect([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown, d.lastSeenAt], [t(17), 'auto', 0, true, t(8, 4)]);
    expect(run([e(inn, t(6, 56))], now: t(23, 55)).overtimeEndUnknown, isFalse);
  });

  test('site checks answered "still here": overtime up to the last one', () {
    final events = [e(inn, t(6, 56)), e(seenT, t(17, 2)), e(seenT, t(17, 32)), e(seenT, t(18, 2))];
    final open = run(events, overtime: true, now: t(18, 10));
    expect([open.closed, open.inside], [false, true]);
    final d = run(events, overtime: true, now: t(23, 55));
    expect([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown], [t(18, 2), 'auto', 62, true]);
    final capped = run([...events, e(seenT, t(20, 5))], overtime: true, now: t(23, 55));
    expect([capped.checkOutAt, capped.overtimeMin, capped.overtimeEndUnknown], [t(20), 180, false]);
  });

  test('a site check that finds them gone checks out at the last time seen', () {
    final gone = AttendanceEvent(out, t(17, 32), check: true);
    final d = run([e(inn, t(8)), e(seenT, t(17, 2)), gone], overtime: true, now: t(17, 40));
    expect([d.checkOutAt, d.checkOutType, d.overtimeMin, d.overtimeEndUnknown], [t(17, 2), 'left', 2, false]);
    final early = run([e(inn, t(8)), AttendanceEvent(out, t(17, 2), check: true)], overtime: true, now: t(17, 5));
    expect([early.checkOutAt, early.overtimeMin], [t(17), 0]);
    expect(run([e(inn, t(8)), e(out, t(18))], now: t(19)).checkOutAt, t(18));
  });

  test('site check GPS fix: there, gone or unknown', () {
    expect(siteCheckResult(distance: 40, accuracy: 15, radius: 100), SiteCheckResult.seen);
    expect(siteCheckResult(distance: 130, accuracy: 40, radius: 100), SiteCheckResult.seen);
    expect(siteCheckResult(distance: 160, accuracy: 5, radius: 100), SiteCheckResult.gone);
    expect(siteCheckResult(distance: 140, accuracy: 5, radius: 100), SiteCheckResult.unknown);
    expect(siteCheckResult(distance: 40, accuracy: 300, radius: 100), SiteCheckResult.unknown);
  });

  // Overtime has to be started (2026-10-25), same as attendance.test.js.
  test('site staff: staying without "Start overtime" counts nothing after the end', () {
    final d = run([e(inn, t(8)), e(out, t(18, 30))], overtime: true, confirm: false, now: t(19));
    expect([d.overtimeOn, d.overtimeMin, d.afterHoursMin, d.countedMin], [false, 0, 90, 540]);
    expect(run([e(inn, t(8))], overtime: true, confirm: false, now: t(23, 55)).overtimeEndUnknown, isFalse);
  });

  test('confirmed at 6 pm, still on site → overtime counts from 5 pm', () {
    final events = [e(inn, t(8)), e(AttendanceEventType.otStart, t(18)), e(out, t(18, 40))];
    final d = run(events, overtime: true, confirm: false, now: t(19));
    expect([d.overtimeConfirmedAt, d.overtimeMin, d.checkOutType], [t(18), 100, 'left']);
    final after = run(
      [e(inn, t(8)), e(out, t(18)), e(AttendanceEventType.otStart, t(18, 10))],
      overtime: true,
      confirm: false,
      now: t(19),
    );
    expect([after.overtimeConfirmedAt, after.overtimeMin], [null, 0]);
    expect(run(events, now: t(19)).overtimeMin, 0);
  });

  test('"Not today" then "Start overtime" (pressed by mistake) → overtime counts from the end', () {
    final events = [e(inn, t(8)), e(AttendanceEventType.otDecline, t(17, 12)), e(AttendanceEventType.otStart, t(17, 40)), e(out, t(18))];
    final d = run(events, overtime: true, confirm: false, now: t(19));
    expect([d.overtimeOn, d.overtimeDeclined, d.overtimeConfirmedAt, d.overtimeMin], [true, true, t(17, 40), 60]);
  });

  test('driving overtime on the day: open while driving, closed at the arrival', () {
    final events = [e(inn, t(7)), e(out, t(15)), e(inn, t(18, 30)), e(out, t(18, 40))];
    DayResult go(DriveOvertime? drive, DateTime now, [List<AttendanceEvent> more = const []]) =>
        run([...events, ...more], overtime: true, confirm: false, leaves: true, now: now, drive: drive);
    final driving = go(DriveOvertime(startAt: t(17)), t(18));
    expect([driving.closed, driving.overtimeOn], [false, true]);
    final home = go(DriveOvertime(startAt: t(17), endAt: t(18, 50), place: 'home'), t(19));
    expect([home.checkOutAt, home.checkOutType, home.overtimeMin, home.overtimeEndUnknown], [t(18, 50), 'arrivedHome', 110, false]);
    final unknown = go(DriveOvertime(startAt: t(17), endAt: t(17, 40)), t(20, 5));
    expect([unknown.checkOutType, unknown.overtimeMin, unknown.overtimeEndUnknown], ['auto', 40, true]);
    final checkOut = go(DriveOvertime(startAt: t(17)), t(18), [e(AttendanceEventType.checkOut, t(17, 30))]);
    expect([checkOut.checkOutAt, checkOut.checkOutType, checkOut.overtimeMin], [t(17, 30), 'manual', 30]);
    final none = go(null, t(19));
    expect([none.checkOutType, none.overtimeMin], ['left', 0]);
  });
}
