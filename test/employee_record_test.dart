import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/documents/company_docs.dart';
import 'package:wpc_crm/features/hr/employee_record.dart';

CompanyDoc policy(String id, {String expiry = '2027-01-01', String cls = 'B', String type = healthInsuranceService}) => CompanyDoc(
      id: id, isFolder: false, section: DocSection.expiring, name: id, expiry: expiry, serviceType: type, insuranceClass: cls,
    );

void main() {
  test('health insurance services, newest expiry first', () {
    final list = healthInsurances([
      policy('old', expiry: '2026-12-01'),
      policy('new', expiry: '2027-12-01'),
      policy('moqeem', type: ''),
      CompanyDoc(id: 'f', isFolder: true, section: DocSection.expiring, name: 'f', serviceType: healthInsuranceService),
    ]);
    expect([for (final p in list) p.id], ['new', 'old']);
  });

  test("a person's insurance: the usual policy and class unless their record differs", () {
    final policies = [policy('p1'), policy('p2', expiry: '2026-12-01', cls: 'VIP')];
    expect(insuranceOf(null, policies)!.policy.id, 'p1');
    expect(insuranceOf(null, policies)!.insuranceClass, 'B');
    final own = insuranceOf(const EmployeeRecord(uid: 'u', insuranceClass: 'A'), policies)!;
    expect((own.insuranceClass, own.ownClass), ('A', true));
    expect(insuranceOf(const EmployeeRecord(uid: 'u', insuranceId: 'p2'), policies)!.insuranceClass, 'VIP');
    expect(insuranceOf(const EmployeeRecord(uid: 'u', insuranceId: 'gone'), policies)!.policy.id, 'p1');
    expect(insuranceOf(const EmployeeRecord(uid: 'u', insuranceId: noInsurance), policies), isNull);
    expect(insuranceOf(null, const []), isNull);
  });

  test('ID renewal: due within the reminder days or expired', () {
    final today = DateTime(2026, 11, 3);
    expect(const EmployeeRecord(uid: 'u', idExpiry: '2026-12-31').idNeedsRenewal(today), isFalse);
    expect(const EmployeeRecord(uid: 'u', idExpiry: '2026-11-20').idNeedsRenewal(today), isTrue);
    expect(const EmployeeRecord(uid: 'u', idExpiry: '2026-10-01').idNeedsRenewal(today), isTrue);
    expect(const EmployeeRecord(uid: 'u').idNeedsRenewal(today), isFalse);
  });

  test('record round trip', () {
    const r = EmployeeRecord(uid: 'u', idType: IdType.nationalId, idNumber: ' 1012 ', idExpiry: '2027-01-01', nationality: 'Saudi');
    final back = EmployeeRecord.fromMap('u', r.toMap());
    expect((back.idType, back.idNumber, back.nationality), (IdType.nationalId, '1012', 'Saudi'));
  });

  test('subscriptions and services expire and are management only; HR edits both', () {
    expect(DocSection.subscription.expires && DocSection.expiring.expires, isTrue);
    expect(DocSection.subscription.salesVisible, isFalse);
    expect(canEditDocSection(UserRole.hr, DocSection.subscription), isTrue);
    expect(canEditDocSection(UserRole.hr, DocSection.official), isFalse);
    expect(docSectionsFor(UserRole.salesExec), [DocSection.official, DocSection.product]);
    expect(docRestrictedUnder(const [], DocSection.subscription, '', false), isTrue);
    final sub = CompanyDoc(id: 's', isFolder: false, section: DocSection.subscription, name: 's', expiry: '2026-11-10');
    expect(sub.hasFile, isFalse);
    expect(sub.needsRenewal(DateTime(2026, 11, 3)), isTrue);
  });
}
