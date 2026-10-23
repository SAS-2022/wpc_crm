import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/settings/page_access.dart';

void main() {
  AppUser user(UserRole role, {bool marked = false}) =>
      AppUser(id: 'u', name: 'u', email: '', phone: '', role: role, kamId: null, active: true, markedManager: marked);

  test('defaults: every role that can have a page has it', () {
    const a = PageAccess.defaults;
    expect(a.allows(UserRole.salesExec, AppPage.clients), isTrue);
    expect(a.allows(UserRole.kam, AppPage.reports), isTrue);
    expect(a.allows(UserRole.warehouseSupervisor, AppPage.drivers), isTrue);
    // Not possible: the data rules don't allow it.
    expect(a.allows(UserRole.driver, AppPage.clients), isFalse);
    expect(a.allows(UserRole.hr, AppPage.users), isFalse);
  });

  test('turning off and on, saved and read back', () {
    final a = PageAccess.defaults.turned(AppPage.reports, UserRole.kam, false).turned(AppPage.map, UserRole.salesExec, false);
    expect(a.allows(UserRole.kam, AppPage.reports), isFalse);
    expect(a.allows(UserRole.gm, AppPage.reports), isTrue);
    final back = PageAccess.fromMap(a.toMap());
    expect(back.allows(UserRole.kam, AppPage.reports), isFalse);
    expect(back.allows(UserRole.salesExec, AppPage.map), isFalse);
    expect(back.turned(AppPage.reports, UserRole.kam, true).allows(UserRole.kam, AppPage.reports), isTrue);
    expect(PageAccess.fromMap({'off': {'nope': ['kam'], 'reports': ['cleaner', 'kam']}}).off, {AppPage.reports: {UserRole.kam}});
  });

  test('settings stay on for SM / GM; marked managers keep attendance', () {
    final a = PageAccess.defaults.turned(AppPage.settings, UserRole.gm, false).turned(AppPage.attendance, UserRole.kam, false);
    expect(a.allows(UserRole.gm, AppPage.settings), isTrue);
    expect(a.allowsUser(user(UserRole.accounting, marked: true), AppPage.attendance), isTrue);
    expect(a.allowsUser(user(UserRole.accounting), AppPage.attendance), isFalse);
    expect(a.allowsUser(user(UserRole.kam), AppPage.attendance), isFalse);
  });

  test('locations map to pages', () {
    expect(AppPage.forLocation('/clients/abc/edit'), AppPage.clients);
    expect(AppPage.forLocation('/settings/page-access'), AppPage.settings);
    expect(AppPage.forLocation('/work-sites'), AppPage.settings);
    expect(AppPage.forLocation('/history'), AppPage.routeHistory);
    expect(AppPage.forLocation('/'), isNull);
    expect(AppPage.forLocation('/clientsx'), isNull);
  });
}
