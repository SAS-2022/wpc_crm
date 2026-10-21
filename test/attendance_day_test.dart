import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_day.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

void main() {
  // Wednesday 2026-10-21; company hours Sat–Thu 08:00–17:00.
  final day = DateTime(2026, 10, 21);
  const hours = WorkHours.defaults;
  PersonDay at(DayResult? d, DateTime now, {bool overtime = false, DateTime? on}) =>
      personDay(d, schedule: hours, overtimeAllowed: overtime, day: on ?? day, now: now);

  test('not checked in: delay since the start counts only today, after the grace', () {
    expect(at(null, DateTime(2026, 10, 21, 8, 10)).lateMin, 0); // within 15 min
    final late = at(null, DateTime(2026, 10, 21, 9, 30));
    expect([late.status, late.lateMin, late.notInYet, late.scheduledMin], [DayStatus.notIn, 90, true, 540]);
    expect(at(null, DateTime(2026, 10, 22, 9)).lateMin, 0); // another day shown
    expect(at(null, DateTime(2026, 10, 23, 10), on: DateTime(2026, 10, 23)).scheduledMin, 0); // Friday off
  });

  test('open day: on site or away, worked so far capped at the end without overtime', () {
    final d = DayResult(checkInAt: DateTime(2026, 10, 21, 8, 30), inside: true, lateMin: 30);
    final noon = at(d, DateTime(2026, 10, 21, 12));
    expect([noon.status, noon.workedMin, noon.lateMin], [DayStatus.onSite, 210, 30]);
    expect(at(d, DateTime(2026, 10, 21, 18)).workedMin, 510); // stops at 17:00
    expect(at(d, DateTime(2026, 10, 21, 18), overtime: true).workedMin, 570);
    final left = DayResult(checkInAt: DateTime(2026, 10, 21, 8), inside: false, lastExitAt: DateTime(2026, 10, 21, 11));
    expect(at(left, DateTime(2026, 10, 21, 12)).status, DayStatus.away);
  });

  test('closed day: counted minutes', () {
    final d = DayResult(
      checkInAt: DateTime(2026, 10, 21, 8),
      checkOutAt: DateTime(2026, 10, 21, 16),
      countedMin: 480,
      inside: false,
    );
    expect([at(d, DateTime(2026, 10, 21, 20)).status, at(d, DateTime(2026, 10, 21, 20)).workedMin], [DayStatus.checkedOut, 480]);
  });
}
