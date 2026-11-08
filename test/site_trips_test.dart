import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';

void main() {
  DateTime t(int h, [int m = 0]) => DateTime(2026, 11, 4, h, m);
  AttendanceEvent e(AttendanceEventType type, DateTime at) => AttendanceEvent(type, at);
  const inn = AttendanceEventType.in_, out = AttendanceEventType.out;

  test('left and came back twice', () {
    final trips = siteTrips([
      e(inn, t(8)),
      e(out, t(11, 20)),
      e(inn, t(12, 5)),
      e(out, t(14)),
      e(AttendanceEventType.checkIn, t(14, 30)),
    ]);
    expect(trips, [(leftAt: t(11, 20), backAt: t(12, 5)), (leftAt: t(14), backAt: t(14, 30))]);
  });

  test('still away now and the final exit are no trips', () {
    expect(siteTrips([e(inn, t(8)), e(out, t(16))]), isEmpty);
  });

  test('short jitter at the edge is ignored', () {
    expect(siteTrips([e(inn, t(8)), e(out, t(9)), e(inn, t(9, 2))]), isEmpty);
  });

  test('check-out ends the stay; checking in again is no trip', () {
    expect(
      siteTrips([e(inn, t(8)), e(AttendanceEventType.checkOut, t(12)), e(AttendanceEventType.checkIn, t(13))]),
      isEmpty,
    );
  });

  test('exit before the first arrival is ignored; order of events does not matter', () {
    final trips = siteTrips([e(inn, t(12)), e(out, t(7)), e(inn, t(8)), e(out, t(10))]);
    expect(trips, [(leftAt: t(10), backAt: t(12))]);
  });

  test('a site check finding them there ends the trip', () {
    final trips = siteTrips([e(inn, t(8)), e(out, t(17, 10)), e(AttendanceEventType.seen, t(17, 40))]);
    expect(trips, [(leftAt: t(17, 10), backAt: t(17, 40))]);
  });

  // 2026-11-07: Wissam inside the Service Center, then the phone's first
  // report for the Showroom (20 km away) said "exit".
  group('exit from another site', () {
    AttendanceEvent at(AttendanceEventType type, DateTime when, String site, {String? source}) =>
        AttendanceEvent(type, when, siteId: site, source: source);

    test('is not leaving: still inside, no trip', () {
      final events = [at(inn, t(8, 32), 'service'), at(out, t(8, 33), 'showroom'), at(inn, t(9), 'service')];
      final d = deriveDay(
        events,
        start: t(8),
        end: t(17),
        closeAll: t(23, 55),
        now: t(10),
        leavesSite: true,
        overtimeAllowed: false,
      );
      expect(d.inside, isTrue);
      expect(d.lastExitAt, isNull);
      expect(siteTrips(events), isEmpty);
    });

    test('an exit from their own site or a GPS exit still counts', () {
      final own = deriveDay(
        [at(inn, t(8), 'service'), at(out, t(9), 'service')],
        start: t(8),
        end: t(17),
        closeAll: t(23, 55),
        now: t(10),
        leavesSite: true,
        overtimeAllowed: false,
      );
      expect(own.inside, isFalse);
      final gps = deriveDay(
        [at(inn, t(8), 'service'), at(out, t(9), 'showroom', source: 'gps')],
        start: t(8),
        end: t(17),
        closeAll: t(23, 55),
        now: t(10),
        leavesSite: true,
        overtimeAllowed: false,
      );
      expect(gps.inside, isFalse);
    });
  });

  test('moving between sites before the start: no exit checked, break counted from the start', () {
    final exits = checkExits([(leftAt: t(7, 59), backAt: t(8, 6))], const [], t(17), start: t(8));
    expect(exits, isEmpty);
    final d = deriveDay(
      [
        AttendanceEvent(inn, t(7, 55), siteId: 'a'),
        AttendanceEvent(out, t(7, 59), siteId: 'a'),
        AttendanceEvent(inn, t(8, 6), siteId: 'b'),
      ],
      start: t(8),
      end: t(17),
      closeAll: t(23, 55),
      now: t(10),
      leavesSite: false,
      overtimeAllowed: false,
      breakAllowanceMin: 60,
    );
    expect(d.inside, isTrue);
    expect(d.breakMin, 6);
  });
}
