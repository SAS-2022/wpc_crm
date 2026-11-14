import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/settings/page_access.dart';

// Department heads get Live tracking, Route history, Phone status (with the
// Employee Map and Attendance) for their own people (user request 2026-11-14).
void main() {
  AppUser u(String id, UserRole role, {bool manager = false}) => AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: null, active: true, markedManager: manager,
      );
  const access = PageAccess.defaults;
  const pages = [
    AppPage.liveTracking,
    AppPage.routeHistory,
    AppPage.phoneStatus,
    AppPage.employeesMap,
    AppPage.attendance,
  ];

  test('factory / logistics manager and "Is a manager" people get the five pages', () {
    for (final head in [
      u('fm', UserRole.factoryManager),
      u('lm', UserRole.logisticsManager),
      u('acc', UserRole.accounting, manager: true),
    ]) {
      expect(head.seesLiveTracking, isTrue, reason: head.id);
      expect(head.seesRouteHistory, isTrue, reason: head.id);
      expect(head.seesPhoneStatus, isTrue, reason: head.id);
      expect(head.seesEmployeesMap, isTrue, reason: head.id);
      expect(head.seesTeamAttendance, isTrue, reason: head.id);
      expect(head.teamScopedMaps, isTrue, reason: head.id);
      for (final p in pages) {
        expect(access.allowsUser(head, p), isTrue, reason: '${head.id} $p');
      }
    }
  });

  test('others unchanged: plain staff none, SM / GM / KAM see everyone or their team', () {
    final acc = u('acc', UserRole.accounting);
    expect(acc.seesLiveTracking || acc.seesRouteHistory || acc.seesPhoneStatus, isFalse);
    for (final p in [AppPage.liveTracking, AppPage.routeHistory, AppPage.phoneStatus]) {
      expect(access.allowsUser(acc, p), isFalse);
    }
    expect(u('sm', UserRole.salesManager).teamScopedMaps, isFalse);
    expect(u('k', UserRole.kam).teamScopedMaps, isFalse);
    // Warehouse supervisor: route history of their people, no live map page.
    final ws = u('ws', UserRole.warehouseSupervisor);
    expect(ws.seesRouteHistory, isTrue);
    expect(ws.seesLiveTracking, isFalse);
  });

  test('a page turned off for the role stays off', () {
    final off = access.turned(AppPage.liveTracking, UserRole.factoryManager, false);
    expect(off.allowsUser(u('fm', UserRole.factoryManager), AppPage.liveTracking), isFalse);
  });
}
