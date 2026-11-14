import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';

void main() {
  test('forklift driver works on site like a worker, not like a company-car driver', () {
    const r = UserRole.forkliftDriver;
    expect(UserRole.fromValue('forklift_driver'), r);
    expect(UserRole.assignable, contains(r));
    expect(UserRole.registrable, contains(r));
    expect(r.isDriver, isFalse);
    expect(r.isLocationTracked, isFalse);
    expect(r.recordsGps, isTrue);
    expect(r.asksForBreaks, isTrue);
    expect(r.leavesSiteForWork, isFalse);
    expect(r.supervisedByWarehouse, isTrue);
    expect(r.isProductionOrLogistics, isTrue);
    expect(r.isBackOffice, isTrue);
    expect(r.isSales, isFalse);
    expect(AppUser.defaultDepartmentOf(r), 'logistics');
    expect(UserRole.logisticsManager.editableRoles, contains(r));
    expect(UserRole.hr.editableRoles, contains(r));
    expect(UserRole.factoryManager.editableRoles, isNot(contains(r)));
  });
}
