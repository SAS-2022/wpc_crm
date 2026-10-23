import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/notifications/notifications.dart';

void main() {
  AppUser u(String id, UserRole role, {String? kamId, bool active = true, String? managerId}) =>
      AppUser(id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: active, managerId: managerId);
  final users = [
    u('exec', UserRole.salesExec, kamId: 'kam'),
    u('lone', UserRole.salesExec),
    u('kam', UserRole.kam),
    u('sm', UserRole.salesManager),
    u('gm', UserRole.gm),
    u('hr', UserRole.hr),
    u('worker', UserRole.worker),
  ];
  List<String> of(String id, [List<AppUser>? list]) => directManagersOf((list ?? users).firstWhere((x) => x.id == id), list ?? users);

  test('exec → their KAM, else the sales managers; KAM → sales managers; others → GMs', () {
    expect(of('exec'), ['kam']);
    expect(of('lone'), ['sm']);
    expect(of('kam'), ['sm']);
    expect(of('sm'), ['gm']);
    expect(of('hr'), ['gm']);
    expect(of('worker'), ['gm']);
    expect(of('gm'), isEmpty);
  });

  test('inactive KAM / no sales manager: falls back', () {
    final noKam = [for (final x in users) x.id == 'kam' ? u('kam', UserRole.kam, active: false) : x];
    expect(of('exec', noKam), ['sm']);
    final noSm = [for (final x in users) if (x.id != 'sm') x];
    expect(of('kam', noSm), ['gm']);
  });

  test('the chosen direct manager wins while active', () {
    final list = [...users, u('acc', UserRole.accounting, managerId: 'hr'), u('exec2', UserRole.salesExec, kamId: 'kam', managerId: 'sm')];
    expect(of('acc', list), ['hr']);
    expect(of('exec2', list), ['sm']);
    final hrGone = [for (final x in list) x.id == 'hr' ? u('hr', UserRole.hr, active: false) : x];
    expect(of('acc', hrGone), ['gm']);
  });

  test('drivers and warehouse supervisors → the logistics manager; who is under whom', () {
    final list = [
      ...users,
      u('lm', UserRole.logisticsManager),
      u('ws', UserRole.warehouseSupervisor),
      AppUser(id: 'd1', name: 'd1', email: '', phone: '', role: UserRole.driver, kamId: null, active: true, supervisorId: 'ws'),
      u('d2', UserRole.driver),
    ];
    expect(of('d1', list), ['lm']);
    expect(of('ws', list), ['lm']);
    expect(of('d2', [...users, u('d2', UserRole.driver)]), ['gm']); // no logistics manager
    AppUser by(String id) => list.firstWhere((x) => x.id == id);
    expect(peopleUnder(by('lm'), list).map((x) => x.id), ['ws', 'd1', 'd2']);
    expect(peopleUnder(by('ws'), list).map((x) => x.id), ['d1']);
    expect(peopleUnder(by('kam'), list).map((x) => x.id), ['exec']);
    expect(driversOf(by('lm'), list).map((x) => x.id), ['d1', 'd2']);
    expect(driversOf(by('ws'), list).map((x) => x.id), ['d1']);
    expect(driversOf(by('kam'), list), isEmpty);
  });
}
