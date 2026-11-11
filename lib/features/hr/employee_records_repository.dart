import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'employee_record.dart';

CollectionReference<Map<String, dynamic>> get _records => FirebaseFirestore.instance.collection('employee_records');

/// Every employee record by uid: the HR area (HR, GM, SM) only.
final employeeRecordsProvider = StreamProvider<Map<String, EmployeeRecord>>((ref) {
  final hr = ref.watch(currentUserProvider.select((u) => u.value?.active == true && u.value!.can.canSeeHr));
  if (!hr) return Stream.value(const {});
  return _records.snapshots().map((s) => {for (final d in s.docs) d.id: EmployeeRecord.fromMap(d.id, d.data())});
});

/// [record] saved as a whole (HR area).
Future<void> saveEmployeeRecord(EmployeeRecord record) => saving(() => _records.doc(record.uid).set({
      ...record.toMap(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));

/// The person's class on their health insurance ('' = the policy's).
Future<void> setInsuranceClass(String uid, String insuranceClass) => saving(() => _records.doc(uid).set({
      'uid': uid,
      'insuranceClass': insuranceClass.trim(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));

/// Renewed Iqama / ID: the new expiry (logged in `idRenewals`).
Future<void> renewEmployeeId(EmployeeRecord record, String expiry) => saving(() => _records.doc(record.uid).set({
      'uid': record.uid,
      'idExpiry': expiry,
      'idRenewals': FieldValue.arrayUnion([
        {'expiry': expiry, 'previous': record.idExpiry, 'byId': FirebaseAuth.instance.currentUser?.uid ?? '', 'at': Timestamp.now()},
      ]),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
