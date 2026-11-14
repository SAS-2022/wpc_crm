import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'payroll.dart';

final _payroll = FirebaseFirestore.instance.collection('payroll');

/// Every employee's salary by uid — only for [canSeePayroll] (rules deny
/// everyone else).
final salariesProvider = StreamProvider<Map<String, SalaryStructure>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (!canSeePayroll(me)) return Stream.value(const {});
  return _payroll.snapshots().map((s) => {for (final d in s.docs) d.id: SalaryStructure.fromDoc(d)});
});

final payrollRepositoryProvider = Provider((ref) => PayrollRepository());

class PayrollRepository {
  /// Saves [uid]'s salary; each change is logged on the doc (when, who, gross).
  /// Parts locked by the employment contract are never written here.
  Future<void> save(String uid, SalaryStructure salary, String byId) => saving(() => _payroll.doc(uid).set({
        ...salary.toMap()..removeWhere((k, _) => salary.isLocked(k)),
        'uid': uid,
        'updatedBy': byId,
        'updatedAt': FieldValue.serverTimestamp(),
        'log': FieldValue.arrayUnion([
          {'at': Timestamp.now(), 'byId': byId, 'gross': salary.monthly},
        ]),
      }, SetOptions(merge: true)));

  /// Writes only the parts read from [uid]'s employment contract (HR may
  /// write these without reading payroll). [gross] is logged when known
  /// (the payroll account).
  Future<void> applyContract(String uid, SalaryUpdate update, String byId, String contractPath, {double? gross}) =>
      _payroll.doc(uid).set({
        ...update.toMap(),
        'uid': uid,
        'contractPath': contractPath,
        'updatedBy': byId,
        'updatedAt': FieldValue.serverTimestamp(),
        'log': FieldValue.arrayUnion([
          {'at': Timestamp.now(), 'byId': byId, 'source': 'contract', 'gross': ?gross},
        ]),
      }, SetOptions(merge: true));
}
