import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';

void main() {
  test('role parsing and permissions', () {
    expect(UserRole.fromValue('kam'), UserRole.kam);
    expect(UserRole.fromValue('unknown'), UserRole.salesExec);
    expect(UserRole.gm.isAdmin, isTrue);
    expect(UserRole.kam.isAdmin, isFalse);
    expect(UserRole.kam.isSupervisor, isTrue);
    expect(UserRole.salesExec.isSupervisor, isFalse);
  });
}
