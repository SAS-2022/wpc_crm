import '../../core/app_user.dart';
import '../documents/company_docs.dart';
import 'employee_record.dart';
import 'payroll.dart';

// Payroll tab filters (user 2026-11-16: "who's iqama is expiring, who's
// details are not complete, and things like that"). Pure logic, unit tested
// in test/employee_completeness_test.dart.

/// A detail HR should have for every employee.
enum MissingDetail { idNumber, idExpiry, nationality, joiningDate, phone }

/// What the Payroll tab can filter by (several ticked = any of them).
enum EmployeeIssue { idExpired, idExpiring, missingDetails, noSalary, noContract, noInsurance }

/// The details missing for [u] ([record] null = nothing entered yet).
List<MissingDetail> missingDetails(AppUser u, EmployeeRecord? record) => [
      if ((record?.idNumber ?? '').trim().isEmpty) MissingDetail.idNumber,
      if (DateTime.tryParse(record?.idExpiry ?? '') == null) MissingDetail.idExpiry,
      if ((record?.nationality ?? '').trim().isEmpty) MissingDetail.nationality,
      if ((u.joiningDate ?? '').isEmpty) MissingDetail.joiningDate,
      if (u.phone.trim().isEmpty) MissingDetail.phone,
    ];

/// Every [EmployeeIssue] that applies to [u]. [insured] = [insuranceOf] found
/// a policy for them.
Set<EmployeeIssue> employeeIssues({
  required AppUser u,
  required EmployeeRecord? record,
  required SalaryStructure salary,
  required bool insured,
  required DateTime today,
}) {
  final id = docExpiryState(record?.idExpiry ?? '', today);
  return {
    if (id == DocExpiryState.expired) EmployeeIssue.idExpired,
    if (id == DocExpiryState.dueSoon) EmployeeIssue.idExpiring,
    if (missingDetails(u, record).isNotEmpty) EmployeeIssue.missingDetails,
    if (!salary.isSet) EmployeeIssue.noSalary,
    if (record?.contract == null) EmployeeIssue.noContract,
    if (!insured) EmployeeIssue.noInsurance,
  };
}

/// [issues] passes the ticked [filter] (empty = everyone; else any of them).
bool matchesIssues(Set<EmployeeIssue> issues, Set<EmployeeIssue> filter) =>
    filter.isEmpty || issues.any(filter.contains);
