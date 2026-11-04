import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/attendance/overtime.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

// "Start overtime?" on the phone (2026-10-25), same conditions as overtimeAskDue in functions/attendance.js.
void main() {
  const hours = WorkHours(days: {1, 2, 3, 4, 5, 6, 7}, startMinute: 480, endMinute: 1020);
  DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 25, h, m);
  AppUser person({UserRole role = UserRole.worker, bool overtime = true}) =>
      AppUser(id: 'w', name: 'W', email: '', phone: '', role: role, kamId: null, active: true, overtimeAllowed: overtime);
  final inside = DayResult(checkInAt: t(8), inside: true);

  test('asked 10 min after the end while still inside, until the cap', () {
    expect(overtimeQuestionPending(person(), inside, hours, t(17, 5)), isFalse);
    expect(overtimeQuestionPending(person(), inside, hours, t(17, 10)), isTrue);
    expect(overtimeQuestionPending(person(), inside, hours, t(19, 59)), isTrue);
    expect(overtimeQuestionPending(person(), inside, hours, t(20, 1)), isFalse); // 3 h cap
  });

  test('not when started, declined, gone, closed, not allowed or a driver', () {
    expect(overtimeQuestionPending(person(), DayResult(checkInAt: t(8), inside: true, overtimeConfirmedAt: t(17, 12)), hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(), DayResult(checkInAt: t(8), inside: true, overtimeDeclined: true), hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(), DayResult(checkInAt: t(8)), hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(), DayResult(checkInAt: t(8), checkOutAt: t(17)), hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(overtime: false), inside, hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(role: UserRole.driver), inside, hours, t(17, 20)), isFalse);
    expect(overtimeQuestionPending(person(), null, hours, t(17, 20)), isFalse);
  });

  test('"Not today" by mistake: the card still offers Start overtime while at the site', () {
    final declined = DayResult(checkInAt: t(8), inside: true, overtimeDeclined: true);
    expect(overtimeQuestionPending(person(), declined, hours, t(17, 20)), isFalse); // no more asking
    expect(overtimeQuestionPending(person(), declined, hours, t(17, 20), afterDecline: true), isTrue);
    expect(overtimeQuestionPending(person(), inside, hours, t(17, 20), afterDecline: true), isFalse);
    expect(overtimeQuestionPending(person(), DayResult(checkInAt: t(8), overtimeDeclined: true), hours, t(17, 20), afterDecline: true), isFalse);
    expect(overtimeQuestionPending(person(), declined, hours, t(20, 5), afterDecline: true), isFalse); // past the cap
  });

  test('approval: the HR area and the person\'s managers, never their own', () {
    final worker = person();
    final gm = AppUser(id: 'gm', name: 'G', email: '', phone: '', role: UserRole.gm, kamId: null, active: true);
    final hr = AppUser(id: 'hr', name: 'H', email: '', phone: '', role: UserRole.hr, kamId: null, active: true);
    final other = AppUser(id: 'o', name: 'O', email: '', phone: '', role: UserRole.worker, kamId: null, active: true);
    final users = [worker, gm, hr, other];
    expect(canApproveOvertime(gm, worker, users), isTrue); // workers' direct manager = GMs
    expect(canApproveOvertime(hr, worker, users), isTrue);
    expect(canApproveOvertime(other, worker, users), isFalse);
    expect(canApproveOvertime(gm, gm, users), isFalse);
  });

  // The real team on 2026-11-03 (factory manager Muhammad Ashraf, logistics
  // manager Mohamed Hassan): each approves their own people, not the other's.
  test('factory and logistics managers approve their teams\' overtime', () {
    AppUser u(String id, UserRole role, {String? dept, String? mgr, String? sup}) => AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: null, active: true,
        department: dept, managerId: mgr, supervisorId: sup);
    final fm = u('fm', UserRole.factoryManager, dept: 'production');
    final lm = u('lm', UserRole.logisticsManager);
    final users = [
      fm, lm,
      u('gm', UserRole.gm), u('sm', UserRole.salesManager),
      u('ws', UserRole.warehouseSupervisor, dept: 'logistics'),
      u('operator', UserRole.operator, dept: 'production'),
      u('operatorChosen', UserRole.operator, dept: 'production', mgr: 'fm'),
      u('engineer', UserRole.engineer, dept: 'production'),
      u('prodWorker', UserRole.worker, dept: 'production', mgr: 'fm'),
      u('driver', UserRole.driver, dept: 'logistics', sup: 'ws'),
      u('driverWarehouse', UserRole.driver, dept: 'warehouse', sup: 'ws'),
    ];
    AppUser by(String id) => users.firstWhere((x) => x.id == id);
    for (final id in ['operator', 'operatorChosen', 'engineer', 'prodWorker']) {
      expect(canApproveOvertime(fm, by(id), users), isTrue, reason: id);
      expect(canApproveOvertime(lm, by(id), users), isFalse, reason: id);
    }
    for (final id in ['driver', 'driverWarehouse']) {
      expect(canApproveOvertime(lm, by(id), users), isTrue, reason: id);
      expect(canApproveOvertime(fm, by(id), users), isFalse, reason: id);
    }
    expect(fm.seesTeamAttendance && lm.seesTeamAttendance, isTrue); // the Home card's query runs for them
    expect(canApproveOvertime(fm, fm, users), isFalse);
  });
}
