import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/core/app_version.dart';

AppUser user(String id, {Map<String, int> builds = const {}, DateTime? reminded}) => AppUser(
      id: id,
      name: id,
      email: '',
      phone: '',
      role: UserRole.salesExec,
      kamId: null,
      active: true,
      appVersions: {
        for (final MapEntry(:key, :value) in builds.entries)
          key: InstalledVersion(version: '1.0.$value', build: value, at: null),
      },
      updateRemindedAt: reminded,
    );

void main() {
  test('latest = own build or the highest any phone reports', () {
    final users = [user('a', builds: {'android': 8}), user('b', builds: {'ios': 9, 'android': 7})];
    expect(latestBuild(users, 8), 9);
    expect(latestBuild(users, 10), 10);
    expect(latestBuild(const [], 3), 3);
  });

  test('outdated platforms: below the latest build only', () {
    final u = user('b', builds: {'ios': 9, 'android': 7});
    expect(outdatedPlatforms(u, 9), ['android']);
    expect(outdatedPlatforms(user('c'), 9), isEmpty); // nothing reported
  });

  test('a reminder at most once a minute per person', () {
    final now = DateTime(2026, 10, 19, 12);
    expect(reminderWait(user('a'), now), Duration.zero);
    expect(reminderWait(user('a', reminded: now.subtract(const Duration(seconds: 20))), now), const Duration(seconds: 40));
    expect(reminderWait(user('a', reminded: now.subtract(const Duration(minutes: 2))), now), Duration.zero);
  });

  test('parses what the app writes, skipping broken entries', () {
    final v = InstalledVersion.parseAll({
      'android': {'version': '1.0.4', 'build': 9},
      'ios': 'bad',
      'web': {'version': 'x'},
    });
    expect(v.keys, ['android']);
    expect(v['android']!.label, '1.0.4 (9)');
  });
}
