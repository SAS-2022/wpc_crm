import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_repository.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/attendance/overtime.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

// Overtime away from the work sites (2026-11-21).
final _end = DateTime(2026, 11, 19, 17);

AttendanceRecord _record(DriveOvertime? drive, [List<AttendanceEvent> events = const []]) =>
    AttendanceRecord(uid: 'ali', date: '2026-11-19', events: events, server: null, drive: drive);

void main() {
  test('asked to confirm while it runs unconfirmed, to start when only asked, never once answered', () {
    final now = _end.add(const Duration(minutes: 20));
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end, field: true)), now, 180), FieldOvertimeAsk.confirm);
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end, field: true, asked: true)), now, 180), FieldOvertimeAsk.start);
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end, field: true, confirmed: true)), now, 180), FieldOvertimeAsk.none);
    // Answered on the phone (the server confirms a little later).
    final answered = [AttendanceEvent(AttendanceEventType.otDecline, now)];
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end, field: true), answered), now, 180), FieldOvertimeAsk.none);
    // Drivers' overtime and no overtime: nothing to ask.
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end)), now, 180), FieldOvertimeAsk.none);
    expect(fieldOvertimeQuestion(_record(null), now, 180), FieldOvertimeAsk.none);
    // Past the cap an unstarted one is gone.
    expect(fieldOvertimeQuestion(_record(DriveOvertime(startAt: _end, field: true, asked: true)), _end.add(const Duration(hours: 4)), 180),
        FieldOvertimeAsk.none);
  });

  test('closes at the last job; an asked one does not keep the day open', () {
    final start = _end.subtract(const Duration(hours: 9));
    final events = [AttendanceEvent(AttendanceEventType.in_, start), AttendanceEvent(AttendanceEventType.out, start.add(const Duration(hours: 1)))];
    DayResult run(DriveOvertime? d) => _record(d, events).result(
          hours: WorkHours.defaults,
          leavesSite: true,
          overtimeAllowed: true,
          overtimeMaxMin: 600,
          now: _end.add(const Duration(hours: 3)),
        );
    final done = run(DriveOvertime(startAt: _end, endAt: _end.add(const Duration(minutes: 120)), place: 'lastJob', field: true));
    expect(done.checkOutType, 'lastJob');
    expect(done.overtimeMin, 120);
    final asked = run(DriveOvertime(startAt: _end, field: true, asked: true));
    expect(asked.closed, isTrue);
    expect(asked.overtimeMin, 0);
  });
}
