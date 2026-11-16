import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/hr/employee_completeness.dart';
import 'package:wpc_crm/features/hr/employee_record.dart';
import 'package:wpc_crm/features/hr/payroll.dart';

void main() {
  final today = DateTime(2026, 11, 16);
  AppUser user({String phone = '0501234567', String? joining = '2024-01-01'}) => AppUser(
        id: 'u',
        name: 'U',
        email: '',
        phone: phone,
        role: UserRole.worker,
        kamId: null,
        active: true,
        joiningDate: joining,
      );
  const complete = EmployeeRecord(
    uid: 'u',
    idNumber: '2123456789',
    idExpiry: '2027-06-01',
    nationality: 'Indian',
    contract: EmploymentContract(storagePath: 'employee_contracts/u/a.pdf', fileName: 'a.pdf'),
  );
  const salary = SalaryStructure(basic: 4000);

  test('nothing missing for a complete record', () {
    expect(missingDetails(user(), complete), isEmpty);
    expect(employeeIssues(u: user(), record: complete, salary: salary, insured: true, today: today), isEmpty);
  });

  test('no record: every record detail missing', () {
    expect(missingDetails(user(phone: '', joining: null), null), MissingDetail.values);
    expect(
      employeeIssues(u: user(), record: null, salary: SalaryStructure.empty, insured: false, today: today),
      {EmployeeIssue.missingDetails, EmployeeIssue.noSalary, EmployeeIssue.noContract, EmployeeIssue.noInsurance},
    );
  });

  test('ID expiring and expired', () {
    EmployeeRecord withExpiry(String e) => EmployeeRecord(
          uid: 'u',
          idNumber: '1',
          idExpiry: e,
          nationality: 'Saudi',
          contract: complete.contract,
        );
    Set<EmployeeIssue> issues(String e) =>
        employeeIssues(u: user(), record: withExpiry(e), salary: salary, insured: true, today: today);
    expect(issues('2026-12-01'), {EmployeeIssue.idExpiring});
    expect(issues('2026-11-10'), {EmployeeIssue.idExpired});
    expect(issues('2027-11-10'), isEmpty);
  });

  test('filter matches any ticked issue', () {
    expect(matchesIssues({EmployeeIssue.noSalary}, {}), isTrue);
    expect(matchesIssues({EmployeeIssue.noSalary}, {EmployeeIssue.noSalary, EmployeeIssue.idExpired}), isTrue);
    expect(matchesIssues({EmployeeIssue.noContract}, {EmployeeIssue.idExpired}), isFalse);
  });
}
