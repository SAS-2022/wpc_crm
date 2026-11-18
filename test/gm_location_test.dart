import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/notifications/notifications.dart';

// The GM is tracked (office hours) and only department heads see it on the
// people maps (user request 2026-11-17).
void main() {
  AppUser u(String id, UserRole role, {bool manager = false, String? dept}) => AppUser(
        id: id, name: id, email: '', phone: '', role: role, kamId: null, active: true,
        markedManager: manager, department: dept,
      );

  final gm = u('gm', UserRole.gm);
  final sm = u('sm', UserRole.salesManager);
  final kam = u('kam', UserRole.kam);
  final exec = u('exec', UserRole.salesExec);
  final fm = u('fm', UserRole.factoryManager);
  final lm = u('lm', UserRole.logisticsManager);
  final hr = u('hr', UserRole.hr, manager: true);
  final hr2 = u('hr2', UserRole.hr);
  final acc = u('acc', UserRole.accounting);
  final users = [gm, sm, kam, exec, fm, lm, hr, hr2, acc];

  test('the GM is tracked during office hours', () {
    expect(UserRole.gm.isLocationTracked, isTrue);
    expect(UserRole.gm.tracksOfficeHours, isTrue);
    expect(UserRole.gm.recordsGps, isFalse);
  });

  test('department heads and GMs see the GM; KAMs and staff do not', () {
    for (final p in [gm, sm, fm, lm, hr]) {
      expect(seesGmLocation(p, users), isTrue, reason: p.id);
    }
    for (final p in [kam, exec, hr2, acc]) {
      expect(seesGmLocation(p, users), isFalse, reason: p.id);
    }
  });
}
