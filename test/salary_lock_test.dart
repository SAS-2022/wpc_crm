import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/hr/payroll.dart';

void main() {
  test('contract parts are locked and kept out of manual saves', () {
    final s = SalaryStructure.fromMap({'basic': 5000, 'housing': 1250, 'transport': 300, 'contractFields': ['basic', 'housing', 'bogus']});
    expect(s.contractFields, {'basic', 'housing'});
    expect(s.isLocked('basic'), isTrue);
    expect(s.isLocked('transport'), isFalse);
    expect(s.toMap().containsKey('contractFields'), isFalse);
  });

  test('a contract update locks exactly the parts it sets', () {
    const u = SalaryUpdate(basic: 6000, others: [OtherAllowance(name: 'Phone', amount: 200)]);
    expect(u.parts, ['basic', 'others']);
    expect(u.toMap()['contractFields'], ['basic', 'others']);
    final s = u.applyTo(const SalaryStructure(basic: 1, housing: 1000, contractFields: {'housing'}));
    expect((s.basic, s.housing, s.otherTotal), (6000.0, 1000.0, 200.0));
    expect(s.contractFields, {'basic', 'others'});
  });
}
