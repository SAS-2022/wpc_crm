import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';

AppUser user(UserRole role, {bool? live, bool attendance = true}) => AppUser(
      id: role.value,
      name: role.value,
      email: '',
      phone: '',
      role: role,
      kamId: null,
      active: true,
      liveTracking: live,
      attendanceRequired: attendance,
      workSiteIds: const ['site'],
    );

void main() {
  test('by role when nothing is set', () {
    for (final r in [UserRole.salesExec, UserRole.kam, UserRole.driver, UserRole.salesManager, UserRole.gm]) {
      expect(user(r).locationTracked, isTrue, reason: r.value);
    }
    for (final r in [UserRole.worker, UserRole.hr, UserRole.accounting, UserRole.factoryManager]) {
      expect(user(r).locationTracked, isFalse, reason: r.value);
      expect(user(r).recordsGps, isTrue, reason: '${r.value} recorded for attendance');
    }
  });

  test('switched on for an office role: tracked live, no longer only recorded', () {
    final w = user(UserRole.worker, live: true);
    expect(w.locationTracked, isTrue);
    expect(w.recordsGps, isFalse);
  });

  test('switched off: a sales exec is not tracked at all, a driver is recorded for attendance', () {
    final e = user(UserRole.salesExec, live: false);
    expect(e.locationTracked, isFalse);
    expect(e.recordsGps, isFalse);
    final d = user(UserRole.driver, live: false);
    expect(d.locationTracked, isFalse);
    expect(d.recordsGps, isTrue);
    expect(user(UserRole.driver, live: false, attendance: false).recordsGps, isFalse);
  });

  test('saved and read back; null clears an earlier choice', () {
    final map = user(UserRole.worker, live: true).toMap();
    expect(map['liveTracking'], isTrue);
    expect(AppUser.fromMap('w', map).liveTracking, isTrue);
    final cleared = user(UserRole.worker).toMap();
    expect(cleared.containsKey('liveTracking'), isTrue);
    expect(cleared['liveTracking'], isNull);
  });
}
