import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';

AppUser _u(UserRole role, {List<String> sites = const [], bool? required}) => AppUser(
    id: 'u', name: 'u', email: '', phone: '', role: role, kamId: null, active: true, workSiteIds: sites, attendanceRequired: required);

void main() {
  test('not set: everyone outside sales, plus sales people with a work site', () {
    expect(_u(UserRole.worker).needsAttendance, isTrue);
    expect(_u(UserRole.hr).needsAttendance, isTrue);
    expect(_u(UserRole.salesExec).needsAttendance, isFalse);
    expect(_u(UserRole.kam, sites: ['s']).needsAttendance, isTrue);
  });

  test('the user form choice wins', () {
    expect(_u(UserRole.worker, required: false).needsAttendance, isFalse);
    expect(_u(UserRole.salesExec, required: true).needsAttendance, isTrue);
  });

  test('checks in only with a work site', () {
    expect(_u(UserRole.worker).checksAttendance, isFalse);
    expect(_u(UserRole.worker, sites: ['s']).checksAttendance, isTrue);
    expect(_u(UserRole.worker, sites: ['s'], required: false).checksAttendance, isFalse);
  });

  test('drivers share their location but are not sales staff', () {
    expect(UserRole.driver.isLocationTracked, isTrue);
    expect(UserRole.driver.isTracked, isFalse);
    expect(UserRole.salesExec.isLocationTracked, isTrue);
    expect(UserRole.worker.isLocationTracked, isFalse);
  });

  test('logistics manager follows drivers; warehouse supervisor is attendance only', () {
    expect(UserRole.fromValue('logistics_manager'), UserRole.logisticsManager);
    expect(UserRole.fromValue('warehouse_supervisor'), UserRole.warehouseSupervisor);
    expect(UserRole.logisticsManager.managesDrivers, isTrue);
    expect(UserRole.logisticsManager.isSupervisor, isFalse);
    expect(UserRole.logisticsManager.isLocationTracked, isFalse);
    expect(UserRole.warehouseSupervisor.managesDrivers, isFalse);
    expect(UserRole.warehouseSupervisor.isBackOffice, isTrue);
    expect(UserRole.gm.managesDrivers, isTrue);
    expect(UserRole.kam.managesDrivers, isFalse);
  });
}
