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
}
