import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/saving.dart';

/// A company people work for (the group's companies), picked when
/// registering (user request 2026-10-19). `companies/{id}`: {name, active};
/// the sales manager / GM manage the list at More → Companies. Readable
/// without signing in, so the registration form can list them.
class Company {
  const Company({required this.id, required this.name, required this.active});

  final String id;
  final String name;
  final bool active;

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => Company(
        id: doc.id,
        name: doc.data()?['name'] as String? ?? '',
        active: doc.data()?['active'] != false,
      );
}

CollectionReference<Map<String, dynamic>> get _companies => FirebaseFirestore.instance.collection('companies');

/// Every company, by name.
final companiesProvider = StreamProvider<List<Company>>((ref) => _companies.snapshots().map(
      (s) => s.docs.map(Company.fromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    ));

final companyNamesProvider = Provider<Map<String, String>>(
  (ref) => {for (final c in ref.watch(companiesProvider).value ?? const <Company>[]) c.id: c.name},
);

Future<void> saveCompany({String? id, required String name, bool active = true}) => saving(
      () => (id == null ? _companies.doc() : _companies.doc(id)).set({'name': name.trim(), 'active': active}),
    );
