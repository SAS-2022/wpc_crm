import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/notifications/notifications.dart';
import 'package:wpc_crm/features/settings/page_access.dart';

// Main role + extra roles (user request 2026-11-11).
void main() {
  AppUser u(String id, UserRole role, {List<UserRole> extra = const [], String? kamId, String? managerId}) => AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: true,
        extraRoles: extra, managerId: managerId,
      );

  test('stored values: known roles only, never the main one, no repeats', () {
    expect(AppUser.extraRolesFrom(['hr', 'hr', 'nonsense', 'accounting', 'kam'], UserRole.kam),
        [UserRole.hr, UserRole.accounting]);
    expect(AppUser.extraRolesFrom(null, UserRole.hr), isEmpty);
  });

  test('capabilities add up; identity stays with the main role', () {
    final hrAcc = u('a', UserRole.hr, extra: [UserRole.accounting]);
    expect(hrAcc.can.canSeeHr, isTrue);
    expect(hrAcc.can.isBackOffice, isTrue);
    expect(hrAcc.hasRole(UserRole.accounting), isTrue);

    // KAM who is also sales manager: admin, sees everyone (not KAM-only).
    final kamSm = u('k', UserRole.kam, extra: [UserRole.salesManager]);
    expect(kamSm.can.isAdmin, isTrue);
    expect(kamSm.kamOnly, isFalse);
    expect(kamSm.role.isTracked, isTrue); // still tracked as a KAM
    expect(u('k2', UserRole.kam).kamOnly, isTrue);

    // Logistics manager + procurement: manages drivers, user list = union.
    final lmProc = u('l', UserRole.logisticsManager, extra: [UserRole.procurement]);
    expect(lmProc.can.managesDrivers, isTrue);
    expect(lmProc.isManager, isTrue);

    // Sales manager + HR: not back office (sales pages stay open).
    final smHr = u('s', UserRole.salesManager, extra: [UserRole.hr]);
    expect(smHr.can.isBackOffice, isFalse);
    expect(smHr.can.managesVehicles, isTrue);

    // An accountant who is also HR edits HR-managed roles.
    final accHr = u('x', UserRole.accounting, extra: [UserRole.hr]);
    expect(accHr.can.managesUsers, isTrue);
    expect(accHr.can.editableRoles, UserRole.hrManagedRoles);
    expect(accHr.role.managesUsers, isFalse);
  });

  test('page access: any role that has the page opens it', () {
    const access = PageAccess.defaults;
    final acc = u('a', UserRole.accounting);
    final accHr = u('b', UserRole.accounting, extra: [UserRole.hr]);
    expect(access.allowsUser(acc, AppPage.hrArea), isFalse);
    expect(access.allowsUser(accHr, AppPage.hrArea), isTrue);
    // Turned off for HR, still on through no other role.
    final off = access.turned(AppPage.hrArea, UserRole.hr, false);
    expect(off.allowsUser(accHr, AppPage.hrArea), isFalse);
  });

  test('someone with an extra manager role is found as a manager', () {
    final users = [
      u('gm', UserRole.gm),
      // A KAM who is also the sales manager.
      u('kamSm', UserRole.kam, extra: [UserRole.salesManager]),
      u('exec', UserRole.salesExec),
      u('kam2', UserRole.kam),
      // HR is someone's extra role: still a GM-reported person.
      u('acc', UserRole.accounting, extra: [UserRole.hr]),
    ];
    AppUser of(String id) => users.firstWhere((x) => x.id == id);
    // An exec without a KAM → the sales managers, including extra ones.
    expect(directManagersOf(of('exec'), users), ['kamSm']);
    expect(directManagersOf(of('kam2'), users), ['kamSm']);
    // The KAM-who-is-SM themselves: KAM's managers = sales managers other than them → GM.
    expect(directManagersOf(of('kamSm'), users), ['gm']);
    // kamId pointing to someone with KAM as an extra role works too.
    final withExtraKam = [...users, u('lm', UserRole.logisticsManager, extra: [UserRole.kam]), u('e2', UserRole.salesExec, kamId: 'lm')];
    expect(directManagersOf(withExtraKam.last, withExtraKam), ['lm']);
  });
}
