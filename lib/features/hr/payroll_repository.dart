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
  Future<void> save(String uid, SalaryStructure salary, String byId) => saving(() => _payroll.doc(uid).set({
        ...salary.toMap(),
        'uid': uid,
        'updatedBy': byId,
        'updatedAt': FieldValue.serverTimestamp(),
        'log': FieldValue.arrayUnion([
          {'at': Timestamp.now(), 'byId': byId, 'gross': salary.monthly},
        ]),
      }, SetOptions(merge: true)));
}
