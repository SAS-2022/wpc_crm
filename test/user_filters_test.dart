import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/users/user_filters.dart';

AppUser u(String name, UserRole role,
        {bool active = true, String approval = '', String email = '', String phone = '', String position = '', String company = '', List<String> sites = const []}) =>
    AppUser(
      id: name,
      name: name,
      email: email,
      phone: phone,
      role: role,
      kamId: null,
      active: active,
      approval: approval,
      position: position,
      companyId: company,
      workSiteIds: sites,
    );

void main() {
  final sami = u('Sami Mansour', UserRole.salesExec, email: 'sami@wpc.com', phone: '+966 55 123 4567', company: 'wpc', sites: ['hq']);
  final ali = u('Ali', UserRole.driver, position: 'driver', company: 'other');
  final newbie = u('New Person', UserRole.unknown, active: false, approval: 'pending');
  final old = u('Old', UserRole.worker, active: false);
  final all = [sami, ali, newbie, old];
  List<String> run(UserFilter f, {Set<String> outdated = const {}}) => [
        for (final x in all)
          if (f.matches(x, roleLabel: (r) => r == UserRole.driver ? 'Driver' : r.value, outdated: (x) => outdated.contains(x.id))) x.id,
      ];

  test('search: name, email, role label, phone digits', () {
    expect(run(const UserFilter(search: 'sami')), ['Sami Mansour']);
    expect(run(const UserFilter(search: 'wpc.com')), ['Sami Mansour']);
    expect(run(const UserFilter(search: 'driv')), ['Ali']);
    expect(run(const UserFilter(search: '0551234567')), isEmpty); // different digits
    expect(run(const UserFilter(search: '1234567')), ['Sami Mansour']);
  });

  test('status chips', () {
    expect(run(const UserFilter(status: UserStatusFilter.active)), ['Sami Mansour', 'Ali']);
    expect(run(const UserFilter(status: UserStatusFilter.pending)), ['New Person']);
    expect(run(const UserFilter(status: UserStatusFilter.inactive)), ['Old']);
    expect(run(const UserFilter(status: UserStatusFilter.olderApp), outdated: {'Ali', 'Old'}), ['Ali']);
  });

  test('roles (any of), company and site combine', () {
    expect(run(const UserFilter(roles: {UserRole.driver, UserRole.salesExec})), ['Sami Mansour', 'Ali']);
    expect(run(const UserFilter(roles: {UserRole.driver, UserRole.salesExec}, companyId: 'wpc')), ['Sami Mansour']);
    expect(run(const UserFilter(siteId: 'hq')), ['Sami Mansour']);
    expect(const UserFilter(roles: {UserRole.driver}, companyId: 'x').sheetCount, 2);
  });
}
