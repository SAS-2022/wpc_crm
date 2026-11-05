import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/attendance/break_request.dart';
import 'package:wpc_crm/features/attendance/overtime.dart';

void main() {
  final day = DateTime(2026, 11, 5);
  DateTime t(int h, [int m = 0]) => day.add(Duration(hours: h, minutes: m));
  BreakSlot slot(String id, DateTime at, BreakStatus status, [int minutes = 30]) =>
      BreakSlot(id: id, at: at, minutes: minutes, status: status);

  group('deriveDay with breaks (same as attendance.test.js)', () {
    final events = [
      AttendanceEvent(AttendanceEventType.in_, t(8)),
      AttendanceEvent(AttendanceEventType.out, t(12)),
    ];
    DayResult run(DateTime now, List<BreakSlot> breaks) => deriveDay(
          events,
          end: t(17),
          closeAll: t(23, 55),
          now: now,
          leavesSite: false,
          overtimeAllowed: false,
          awayGrace: const Duration(minutes: 30),
          breaks: breaks,
        );

    test('approved: break + grace before checking out as left the site', () {
      final approved = [slot('b', t(11, 58), BreakStatus.approved)];
      expect(run(t(12, 50), approved).closed, isFalse);
      final late = run(t(13), approved);
      expect([late.checkOutAt, late.checkOutType], [t(12), 'leftSite']);
    });

    test('refused / pending / asked after leaving: the usual grace', () {
      expect(run(t(12, 30), [slot('b', t(11, 58), BreakStatus.rejected)]).checkOutType, 'leftSite');
      expect(run(t(12, 30), [slot('b', t(11, 58), BreakStatus.pending)]).checkOutType, 'leftSite');
      expect(run(t(12, 40), [slot('b', t(12, 10), BreakStatus.approved)]).checkOutType, 'leftSite');
    });
  });

  test('daily break: up to the allowance free, the rest off the counted time (same as attendance.test.js)', () {
    List<AttendanceEvent> trips(DateTime back1, DateTime back2) => [
          AttendanceEvent(AttendanceEventType.in_, t(8)),
          AttendanceEvent(AttendanceEventType.out, t(10)),
          AttendanceEvent(AttendanceEventType.in_, back1),
          AttendanceEvent(AttendanceEventType.out, t(13)),
          AttendanceEvent(AttendanceEventType.in_, back2),
          AttendanceEvent(AttendanceEventType.out, t(17, 5)),
        ];
    DayResult run(List<AttendanceEvent> e, {int? allowance = 60, DateTime? now}) => deriveDay(
          e,
          end: t(17),
          closeAll: t(23, 55),
          now: now ?? t(18),
          leavesSite: false,
          overtimeAllowed: false,
          awayGrace: const Duration(minutes: 240),
          breakAllowanceMin: allowance,
        );
    final ok = run(trips(t(10, 30), t(13, 30)));
    expect([ok.breakMin, ok.breakOverMin, ok.countedMin], [60, 0, 540]);
    final over = run(trips(t(10, 30), t(13, 50)));
    expect([over.breakMin, over.breakOverMin, over.countedMin], [80, 20, 520]);
    expect(run(trips(t(10, 30), t(13, 50)), allowance: null).breakMin, isNull);
    final out = [AttendanceEvent(AttendanceEventType.in_, t(8)), AttendanceEvent(AttendanceEventType.out, t(10))];
    expect(run(out, now: t(10, 20)).breakMin, 20);
  });

  test('each exit takes the latest unused request asked before it', () {
    final take = breakTaker([
      slot('old', t(9), BreakStatus.rejected, 15),
      slot('new', t(13, 55), BreakStatus.approved),
    ]);
    expect(take(t(14))?.id, 'new');
    expect(take(t(15))?.id, 'old');
    expect(take(t(16)), isNull);
    expect(breakTaker([slot('x', t(10, 4), BreakStatus.approved)])(t(10))?.id, 'x'); // 5 min slack
  });

  test('checkExits: on break, over the break, without permission; after the end left out', () {
    final checks = checkExits(
      [
        (leftAt: t(10), backAt: t(10, 40)),
        (leftAt: t(14), backAt: t(14, 10)),
        (leftAt: t(17, 30), backAt: null),
      ],
      [slot('b', t(9, 58), BreakStatus.approved)],
      t(17),
    );
    expect(checks.length, 2);
    expect(checks[0].permission, ExitPermission.onBreak);
    expect(checks[0].overMin, 10);
    expect(checks[0].withoutPermission, isFalse);
    expect(checks[1].permission, ExitPermission.none);
    expect(checks[1].withoutPermission, isTrue);
  });

  AppUser u(String id, UserRole role, {String? supervisorId, String? department, bool manager = false, String? managerId}) =>
      AppUser(
        id: id,
        name: id,
        email: '',
        phone: '',
        role: role,
        kamId: null,
        active: true,
        supervisorId: supervisorId,
        department: department,
        markedManager: manager,
        managerId: managerId,
      );

  test('break approvers: warehouse supervisor + department head, else direct managers', () {
    final users = [
      u('w', UserRole.worker, supervisorId: 'ws'),
      u('pw', UserRole.worker, department: 'production', supervisorId: 'ws'),
      u('op', UserRole.operator),
      u('ws', UserRole.warehouseSupervisor),
      u('lm', UserRole.logisticsManager),
      u('fm', UserRole.factoryManager),
      u('gm', UserRole.gm),
    ];
    AppUser by(String id) => users.firstWhere((x) => x.id == id);
    expect(breakApproversOf(by('w'), users), ['ws', 'lm']); // no department: the direct manager
    expect(breakApproversOf(by('pw'), users), ['ws', 'fm']);
    expect(breakApproversOf(by('op'), users), ['fm']);
    expect(breakApproversOf(by('ws'), users), ['lm']);
    expect(UserRole.worker.asksForBreaks && UserRole.operator.asksForBreaks && UserRole.warehouseSupervisor.asksForBreaks, isTrue);
    expect(UserRole.driver.asksForBreaks || UserRole.accounting.asksForBreaks, isFalse);
  });

  test('overtime permission: department head / direct manager / admins, never oneself', () {
    final users = [
      u('acc', UserRole.accounting),
      u('accBoss', UserRole.accounting, manager: true),
      u('pw', UserRole.worker, department: 'production'),
      u('fm', UserRole.factoryManager),
      u('ws', UserRole.warehouseSupervisor),
      u('w', UserRole.worker, supervisorId: 'ws'),
      u('sm', UserRole.salesManager),
    ];
    AppUser by(String id) => users.firstWhere((x) => x.id == id);
    expect(canSetOvertimeFor(by('accBoss'), by('acc'), users), isTrue);
    expect(canSetOvertimeFor(by('accBoss'), by('pw'), users), isFalse);
    expect(canSetOvertimeFor(by('fm'), by('pw'), users), isTrue);
    expect(canSetOvertimeFor(by('ws'), by('w'), users), isFalse); // supervisor, not department head
    expect(canSetOvertimeFor(by('sm'), by('w'), users), isTrue);
    expect(canSetOvertimeFor(by('accBoss'), by('accBoss'), users), isFalse);
  });
}
