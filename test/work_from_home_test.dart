import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/attendance/attendance_calendar.dart';
import 'package:wpc_crm/features/attendance/attendance_day.dart';
import 'package:wpc_crm/features/hr/leave_rules.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

// Annual leave worked from home (2026-11-21).
void main() {
  AppUser u(String id, UserRole role, {bool manager = false, String? dept}) => AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: null, active: true,
        markedManager: manager, department: dept,
      );

  test('every 2 work days from home use 1 annual day by default; the ratio is a setting', () {
    expect(wfhLeaveDays(4, 2), 2);
    expect(wfhLeaveDays(3, 2), 1.5);
    expect(wfhLeaveDays(1, 2), 0.5);
    expect(wfhLeaveDays(5, 3), 1.67);
    expect(wfhLeaveDays(5, 1), 5);
    expect(wfhRatioOf(null), defaultWfhDaysPerLeaveDay);
    expect(wfhRatioOf(3), 3);
    expect(wfhRatioOf(1.5), 1.5);
    expect(wfhRatioOf(0), defaultWfhDaysPerLeaveDay);
    expect(wfhRatioOf(50), defaultWfhDaysPerLeaveDay);
    expect(wfhRatioOf('2'), defaultWfhDaysPerLeaveDay);
  });

  test('the sales team and department heads may work from home; other staff not', () {
    final gm = u('gm', UserRole.gm);
    final fm = u('fm', UserRole.factoryManager);
    final op = u('op', UserRole.operator);
    final exec = u('exec', UserRole.salesExec);
    final kam = u('kam', UserRole.kam);
    final acc = u('acc', UserRole.accounting, manager: true);
    final acc2 = u('acc2', UserRole.accounting);
    final users = [gm, fm, op, exec, kam, acc, acc2];
    expect(mayWorkFromHome(exec, users), isTrue);
    expect(mayWorkFromHome(kam, users), isTrue);
    expect(mayWorkFromHome(fm, users), isTrue); // head of production
    expect(mayWorkFromHome(acc, users), isTrue); // head of accounting
    expect(mayWorkFromHome(op, users), isFalse);
    expect(mayWorkFromHome(acc2, users), isFalse);
  });

  test('attendance shows "Working from home · On leave": day view and calendar', () {
    final day = DateTime(2026, 11, 19);
    final p = personDay(null, schedule: WorkHours.defaults, overtimeAllowed: false, day: day,
        now: day.add(const Duration(hours: 12)), onLeave: true, workingFromHome: true);
    expect(p.status, DayStatus.workingFromHome);
    expect(personDay(null, schedule: WorkHours.defaults, overtimeAllowed: false, day: day,
        now: day.add(const Duration(hours: 12)), onLeave: true).status, DayStatus.onLeave);
    final marks = markMonth(
      month: DateTime(2026, 11),
      attended: const {},
      workDays: WorkHours.defaults.days,
      holidays: const {},
      leaveDays: const {'2026-11-18', '2026-11-19'},
      wfhDays: const {'2026-11-19'},
      since: DateTime(2026, 11, 1),
      today: DateTime(2026, 11, 20),
    );
    expect(marks[DateTime(2026, 11, 18)], DayMark.leave);
    expect(marks[DateTime(2026, 11, 19)], DayMark.wfh);
  });
}
