import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/hr/leave_rules.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

AppUser _u(String id, UserRole role, {String? kamId, String? managerId, bool active = true}) => AppUser(
      id: id,
      name: id,
      email: '',
      phone: '',
      role: role,
      kamId: kamId,
      managerId: managerId,
      active: active,
    );

void main() {
  final workDays = WorkHours.defaults.days; // Saturday–Thursday

  group('leaveDays', () {
    // 2026-10-15 is a Thursday, 10-16 Friday, 10-17 Saturday.
    test('work-day types skip Fridays and holidays', () {
      expect(
        leaveDays(
          from: DateTime(2026, 10, 15),
          to: DateTime(2026, 10, 18),
          calendarDays: false,
          workDays: workDays,
          holidays: const {},
        ),
        3,
      );
      expect(
        leaveDays(
          from: DateTime(2026, 10, 15),
          to: DateTime(2026, 10, 18),
          calendarDays: false,
          workDays: workDays,
          holidays: const {'2026-10-17'},
        ),
        2,
      );
    });

    test('calendar-day types count every day', () {
      expect(
        leaveDays(
          from: DateTime(2026, 10, 15),
          to: DateTime(2026, 10, 18),
          calendarDays: true,
          workDays: workDays,
          holidays: const {'2026-10-17'},
        ),
        4,
      );
    });

    test('half day only for a single work day', () {
      double half(DateTime d) =>
          leaveDays(from: d, to: d, calendarDays: false, workDays: workDays, holidays: const {}, halfDay: true);
      expect(half(DateTime(2026, 10, 15)), 0.5);
      expect(half(DateTime(2026, 10, 16)), 0); // Friday
    });
  });

  group('approvalChain', () {
    final users = [
      _u('exec', UserRole.salesExec, kamId: 'kam'),
      _u('kam', UserRole.kam),
      _u('sm', UserRole.salesManager),
      _u('gm', UserRole.gm),
      _u('hr', UserRole.hr),
      _u('acc', UserRole.accounting),
    ];
    List<String> chain(String id, [List<AppUser>? list]) {
      final all = list ?? users;
      return [for (final s in approvalChain(all.firstWhere((u) => u.id == id), all)) s.awaitingKey];
    }

    test('direct manager, then HR', () {
      expect(chain('exec'), ['uid:kam', 'role:hr']);
      expect(chain('kam'), ['uid:sm', 'role:hr']);
      expect(chain('sm'), ['uid:gm', 'role:hr']);
      expect(chain('acc'), ['uid:gm', 'role:hr']);
      // No direct manager: HR only. HR's own request: their manager only.
      expect(chain('gm'), ['role:hr']);
      expect(chain('hr'), ['uid:gm']);
      // The manager chosen on the user form comes first.
      final chosen = [...users.where((u) => u.id != 'acc'), _u('acc', UserRole.accounting, managerId: 'sm')];
      expect(chain('acc', chosen), ['uid:sm', 'role:hr']);
      // Several automatic managers: any of them.
      final twoSm = [...users, _u('sm2', UserRole.salesManager)];
      expect(chain('kam', twoSm), ['role:sales_manager', 'role:hr']);
      // An HR person as direct manager approves once.
      final hrBoss = [...users.where((u) => u.id != 'acc'), _u('acc', UserRole.accounting, managerId: 'hr')];
      expect(chain('acc', hrBoss), ['role:hr']);
    });

    test('without an HR account the sales manager stands in, else the GM', () {
      final noHr = users.where((u) => u.role != UserRole.hr).toList();
      expect(chain('exec', noHr), ['uid:kam', 'role:sales_manager']);
      // The SM's manager is the GM, who also stands in for HR: asked once.
      expect(chain('sm', noHr), ['role:gm']);
      expect(chain('gm', noHr), ['role:sales_manager']);
      final kamGone = [for (final u in users) u.id == 'kam' ? _u('kam', UserRole.kam, active: false) : u];
      expect(chain('exec', kamGone), ['uid:sm', 'role:hr']);
      final alone = [_u('gm', UserRole.gm)];
      expect(chain('gm', alone), isEmpty);
    });

    test('informed: the GM always, the sales managers too for sales executives, never an approver', () {
      List<String> watchers(String id, [List<AppUser>? list]) {
        final all = list ?? users;
        final me = all.firstWhere((u) => u.id == id);
        return leaveWatchers(me, approvalChain(me, all), all);
      }
      expect(watchers('exec'), unorderedEquals(['sm', 'gm']));
      expect(watchers('kam'), ['gm']); // the SM approves
      expect(watchers('acc'), isEmpty); // the GM approves
      expect(watchers('gm'), isEmpty);
      final logistics = [...users, _u('lm', UserRole.logisticsManager), _u('drv', UserRole.driver)];
      expect(chain('drv', logistics), ['uid:lm', 'role:hr']);
      expect(watchers('drv', logistics), ['gm']);
    });

    test('only the current step\'s person decides, never the requester', () {
      final sm = users.firstWhere((u) => u.id == 'sm');
      expect(canDecide(me: sm, requesterId: 'exec', awaitingKey: 'role:sales_manager'), isTrue);
      expect(canDecide(me: sm, requesterId: 'exec', awaitingKey: 'uid:kam'), isFalse);
      expect(canDecide(me: sm, requesterId: 'sm', awaitingKey: 'role:sales_manager'), isFalse);
      expect(canDecide(me: sm, requesterId: 'exec', awaitingKey: null), isFalse);
    });
  });

  test('balances: entitled (person or type) + adjustments − approved − pending, per year', () {
    final b = leaveBalances(
      types: LeaveType.defaults,
      year: 2026,
      entitledOverride: const {'annual': 30},
      adjustments: const [(typeId: 'annual', days: 5), (typeId: 'sick', days: -1)],
      requests: const [
        (typeId: 'annual', from: null, year: 2026, days: 3, status: LeaveStatus.approved),
        (typeId: 'annual', from: null, year: 2026, days: 2, status: LeaveStatus.pending),
        (typeId: 'annual', from: null, year: 2026, days: 9, status: LeaveStatus.rejected),
        (typeId: 'annual', from: null, year: 2026, days: 4, status: LeaveStatus.cancelled),
        (typeId: 'annual', from: null, year: 2025, days: 7, status: LeaveStatus.approved),
      ],
    );
    expect(b['annual']!.entitled, 35);
    expect(b['annual']!.used, 3);
    expect(b['annual']!.pending, 2);
    expect(b['annual']!.remaining, 30);
    expect(b['sick']!.entitled, 119);
    // Unpaid leave and non-leave requests keep no balance.
    expect(b.containsKey('unpaid'), isFalse);
    expect(b.containsKey('salaryCertificate'), isFalse);
  });

  test('leave types survive a save / load round trip', () {
    for (final t in LeaveType.defaults) {
      final back = LeaveType.fromMap(t.toMap());
      expect(back.toMap(), t.toMap());
    }
    expect(LeaveType.defaults.map((t) => t.id).toSet().length, LeaveType.defaults.length);
  });

  group('leave years (joining date)', () {
    test('without a joining date: the calendar year', () {
      expect(leaveYearOf(null, DateTime(2026, 3, 1)), 2026);
      expect(leaveYearRange(null, 2026), (start: DateTime(2026), end: DateTime(2026, 12, 31)));
    });

    test('from the joining anniversary to the day before the next', () {
      expect(leaveYearOf('2023-03-15', DateTime(2026, 3, 14)), 2025);
      expect(leaveYearOf('2023-03-15', DateTime(2026, 3, 15)), 2026);
      expect(leaveYearOf('2023-03-15', DateTime(2026, 12, 31)), 2026);
      expect(leaveYearRange('2023-03-15', 2026), (start: DateTime(2026, 3, 15), end: DateTime(2027, 3, 14)));
    });

    test('joined on 29 February', () {
      expect(leaveYearRange('2024-02-29', 2025), (start: DateTime(2025, 2, 28), end: DateTime(2026, 2, 27)));
      expect(leaveYearOf('2024-02-29', DateTime(2028, 2, 29)), 2028);
    });

    test('requests count in the leave year of their first day; carried days', () {
      final b = leaveBalances(
        types: LeaveType.defaults,
        year: 2026,
        joiningDate: '2023-03-15',
        entitledOverride: const {},
        adjustments: const [],
        carried: const {'annual': -4},
        requests: const [
          (typeId: 'annual', year: 2026, from: '2026-03-10', days: 5, status: LeaveStatus.approved),
          (typeId: 'annual', year: 2027, from: '2027-01-10', days: 2, status: LeaveStatus.approved),
          (typeId: 'annual', year: 2027, from: '2027-03-20', days: 9, status: LeaveStatus.approved),
        ],
      );
      expect(b['annual']!.used, 2);
      expect(b['annual']!.carried, -4);
      expect(b['annual']!.remaining, 15);
    });

    test('carry: overdrawn days always, days left only when allowed', () {
      expect(annualCarry(-3, carryOver: false), -3);
      expect(annualCarry(-3, carryOver: true), -3);
      expect(annualCarry(6, carryOver: false), 0);
      expect(annualCarry(6, carryOver: true), 6);
    });
  });
}
