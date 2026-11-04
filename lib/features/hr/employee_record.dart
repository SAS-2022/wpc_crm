import '../documents/company_docs.dart';

// Employee records (user request 2026-11-03): each person's Iqama or national
// ID (number + expiry, reminded to HR / GM / SM 30 and 15 days before and
// every day after it runs out), nationality and health insurance. Kept in
// Firestore `employee_records/{uid}`, not on `users/{uid}`: users docs are
// read by every active user, these only by the HR area and the person.
// Health insurance comes from the "Services that expire" section: a service
// marked health insurance covers every employee (policy, number, expiry and
// its usual class); a person's record only holds what differs — another
// policy, no insurance, or their own class.

enum IdType {
  iqama,
  nationalId;

  static IdType fromValue(Object? v) => v == 'nationalId' ? nationalId : iqama;
}

/// [insuranceId] value: the person has no company health insurance.
const noInsurance = 'none';

class EmployeeRecord {
  const EmployeeRecord({
    required this.uid,
    this.idType = IdType.iqama,
    this.idNumber = '',
    this.idExpiry = '',
    this.nationality = '',
    this.insuranceId = '',
    this.insuranceClass = '',
  });

  final String uid;
  final IdType idType;
  final String idNumber;

  /// 'yyyy-MM-dd' ('' = not entered).
  final String idExpiry;
  final String nationality;

  /// The health insurance service ('' = the company's usual one,
  /// [noInsurance] = not covered).
  final String insuranceId;

  /// Their class when it differs from the policy's ('' = the policy's).
  final String insuranceClass;

  bool get hasId => idNumber.isNotEmpty || idExpiry.isNotEmpty;

  /// Expired or within App settings `docRenewalDays` (30).
  bool idNeedsRenewal(DateTime today) => docExpiryState(idExpiry, today).index >= DocExpiryState.dueSoon.index;

  factory EmployeeRecord.fromMap(String uid, Map<String, dynamic> d) => EmployeeRecord(
        uid: uid,
        idType: IdType.fromValue(d['idType']),
        idNumber: d['idNumber'] as String? ?? '',
        idExpiry: d['idExpiry'] as String? ?? '',
        nationality: d['nationality'] as String? ?? '',
        insuranceId: d['insuranceId'] as String? ?? '',
        insuranceClass: d['insuranceClass'] as String? ?? '',
      );

  Map<String, Object> toMap() => {
        'uid': uid,
        'idType': idType.name,
        'idNumber': idNumber.trim(),
        'idExpiry': idExpiry,
        'nationality': nationality.trim(),
        'insuranceId': insuranceId,
        'insuranceClass': insuranceClass.trim(),
      };
}

/// The health insurance services, the company's usual one first (latest
/// expiry first, so a renewed policy added as a new item wins).
List<CompanyDoc> healthInsurances(List<CompanyDoc> docs) =>
    [for (final d in docs) if (d.isHealthInsurance) d]..sort((a, b) => b.expiry.compareTo(a.expiry));

/// A person's health insurance: the policy and their class.
typedef PersonInsurance = ({CompanyDoc policy, String insuranceClass, bool ownClass});

/// [record]'s insurance from [policies] ([healthInsurances]); null = none
/// (no policy entered, or marked not covered). A chosen policy that was
/// deleted falls back to the usual one.
PersonInsurance? insuranceOf(EmployeeRecord? record, List<CompanyDoc> policies) {
  if (policies.isEmpty || record?.insuranceId == noInsurance) return null;
  final policy = policies.where((p) => p.id == record?.insuranceId).firstOrNull ?? policies.first;
  final own = record?.insuranceClass ?? '';
  return (policy: policy, insuranceClass: own.isNotEmpty ? own : policy.insuranceClass, ownClass: own.isNotEmpty);
}

/// Common nationalities offered while typing (any text may be entered).
const commonNationalities = [
  'Saudi', 'Egyptian', 'Indian', 'Pakistani', 'Bangladeshi', 'Filipino', 'Nepali', 'Sri Lankan',
  'Syrian', 'Lebanese', 'Jordanian', 'Palestinian', 'Sudanese', 'Yemeni', 'Ethiopian', 'Kenyan',
  'Indonesian', 'Turkish', 'Moroccan', 'Tunisian', 'Algerian', 'Iraqi', 'Afghan', 'Ugandan',
];
