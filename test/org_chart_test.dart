import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/users/org_chart.dart';

void main() {
  AppUser u(String id, UserRole role,
          {String? kamId, bool active = true, String? managerId, String? supervisorId, String approval = ''}) =>
      AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: active,
        managerId: managerId, supervisorId: supervisorId, approval: approval,
      );

  List<String> kids(OrgNode n) => [for (final c in n.children) c.user.id];
  OrgNode find(List<OrgNode> roots, String id) => roots.expand((r) => r.all).firstWhere((n) => n.user.id == id);

  final users = [
    u('gm', UserRole.gm),
    u('sm', UserRole.salesManager),
    u('kam', UserRole.kam),
    u('exec', UserRole.salesExec, kamId: 'kam'),
    u('lone', UserRole.salesExec),
    u('lm', UserRole.logisticsManager),
    u('ws', UserRole.warehouseSupervisor),
    u('driver', UserRole.driver, supervisorId: 'ws'),
    u('driver2', UserRole.driver),
    u('hr', UserRole.hr),
    u('old', UserRole.worker, active: false),
    u('new', UserRole.worker, approval: 'pending'),
  ];

  test('GM on top, each person under their manager', () {
    final roots = buildOrgChart(users);
    expect([for (final r in roots) r.user.id], ['gm']);
    final gm = roots.single;
    expect(kids(gm), ['sm', 'lm', 'hr']);
    expect(kids(find(roots, 'sm')), ['kam', 'lone']);
    expect(kids(find(roots, 'kam')), ['exec']);
    // A driver with a warehouse supervisor sits under them, others under the LM.
    expect(kids(find(roots, 'lm')), ['ws', 'driver2']);
    expect(kids(find(roots, 'ws')), ['driver']);
    expect(gm.teamSize, 9);
  });

  test('inactive and pending people are left out', () {
    final all = buildOrgChart(users).expand((r) => r.all).map((n) => n.user.id);
    expect(all, isNot(contains('old')));
    expect(all, isNot(contains('new')));
  });

  test('several automatic managers: under the first, the others listed', () {
    final list = [...users, u('sm2', UserRole.salesManager)];
    final roots = buildOrgChart(list);
    final lone = find(roots, 'lone');
    expect(lone.alsoUnder, ['sm2']);
  });

  test('a loop of chosen managers does not hide people', () {
    final list = [
      u('a', UserRole.accounting, managerId: 'b'),
      u('b', UserRole.accounting, managerId: 'a'),
    ];
    final roots = buildOrgChart(list);
    final ids = roots.expand((r) => r.all).map((n) => n.user.id).toSet();
    expect(ids, {'a', 'b'});
  });

  test('a manager outside HR / admin sees their own branch', () {
    final lm = users.firstWhere((x) => x.id == 'lm');
    final mine = orgChartFor(lm, users);
    expect([for (final r in mine) r.user.id], ['lm']);
    final gm = users.firstWhere((x) => x.id == 'gm');
    expect(orgChartFor(gm, users).single.user.id, 'gm');
  });
}
