import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';

void main() {
  test('role parsing and permissions', () {
    expect(UserRole.fromValue('kam'), UserRole.kam);
    expect(UserRole.gm.isAdmin, isTrue);
    expect(UserRole.kam.isAdmin, isFalse);
    expect(UserRole.kam.isSupervisor, isTrue);
    expect(UserRole.salesExec.isSupervisor, isFalse);
  });

  test('unknown or missing roles get no access, never sales exec', () {
    for (final v in ['unknown', 'cleaner', '', null]) {
      final r = UserRole.fromValue(v);
      expect(r, UserRole.unknown);
      expect(r.isSales || r.isTracked || r.isSupervisor || r.isBackOffice || r.canSeeHr, isFalse);
    }
    expect(UserRole.assignable, isNot(contains(UserRole.unknown)));
  });

  test('back-office roles: no sales features, HR area for HR / GM / sales manager', () {
    for (final r in [UserRole.hr, UserRole.accounting, UserRole.procurement]) {
      expect(UserRole.fromValue(r.value), r);
      expect(r.isBackOffice, isTrue);
      expect(r.isSales || r.isTracked || r.isSupervisor || r.isAdmin, isFalse);
    }
    expect([for (final r in UserRole.assignable) if (r.isHr) r], [UserRole.gm, UserRole.hr]);
    expect([for (final r in UserRole.assignable) if (r.canManageHr) r],
        [UserRole.salesManager, UserRole.gm, UserRole.hr]);
    expect([for (final r in UserRole.assignable) if (r.canSeeHr) r],
        [UserRole.salesManager, UserRole.gm, UserRole.hr]);
    expect([for (final r in UserRole.assignable) if (r.isSales) r],
        [UserRole.salesExec, UserRole.kam, UserRole.salesManager, UserRole.gm]);
  });

  test('who manages which users', () {
    expect(UserRole.gm.editableRoles, UserRole.assignable);
    expect(UserRole.salesManager.managesUsers, isTrue);
    expect(UserRole.logisticsManager.managesUsers, isTrue);
    expect(UserRole.logisticsManager.editableRoles, [UserRole.driver]);
    expect(UserRole.kam.managesUsers, isFalse);
    expect(UserRole.kam.editableRoles, isEmpty);
  });
}
