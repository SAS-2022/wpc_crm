import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../import/import_plan.dart';
import '../import/location_import.dart';
import 'client.dart';

/// Clients the signed-in user may see: all for KAM/managers, own for sales execs.
final clientsProvider = StreamProvider<List<Client>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('clients');
  if (!me.role.isSupervisor) query = query.where('assignedTo', isEqualTo: me.id);
  return query.snapshots().map(
        (s) => s.docs.map(Client.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// Sales executive filter shared by the client list and map.
/// null = everyone, [unassignedFilter] = clients without a sales executive.
final salesFilterProvider = NotifierProvider<SalesFilter, String?>(SalesFilter.new);
const unassignedFilter = '_unassigned';

class SalesFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final filteredClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final filter = ref.watch(salesFilterProvider);
  return ref.watch(clientsProvider).whenData(
        (list) => filter == null
            ? list
            : list
                .where((c) => filter == unassignedFilter ? c.assignedTo == null : c.assignedTo == filter)
                .toList(),
      );
});

final clientsRepositoryProvider = Provider((ref) => ClientsRepository());

class ClientsRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _clients => _db.collection('clients');

  /// Adds a client by hand (not from Odoo); returns its id.
  Future<String> create(Map<String, dynamic> data, {required String createdBy}) async {
    final ref = await _clients.add({
      ...data,
      'nameKey': Client.normalizeName(data['name'] as String),
      'aliases': const <String>[],
      'tags': '',
      'odooSalesperson': '',
      'googlePin': '',
      'lastVisitAt': null,
      'source': 'manual',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String clientId, Map<String, dynamic> data) =>
      _clients.doc(clientId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// Sets the location of matched clients (from a "name → location" sheet).
  Future<void> updateLocations(List<LocationUpdate> updates) async {
    for (var i = 0; i < updates.length; i += 400) {
      final batch = _db.batch();
      for (final u in updates.skip(i).take(400)) {
        batch.update(_clients.doc(u.client.id), {
          'lat': u.coords.lat,
          'lng': u.coords.lng,
          if (u.row.link.isNotEmpty) 'googlePin': u.row.link,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Adds the unmatched rows of a "name → location" sheet as new clients,
  /// assigned through `users.odooName`, and records an `import_batches` entry.
  Future<void> createFromLocationSheet(
    List<NewLocationClient> rows, {
    required Map<String, String> uidBySalesperson,
    required String fileName,
    required String importedBy,
    required String defaultCategory,
  }) async {
    final batchRef = _db.collection('import_batches').doc();
    for (var i = 0; i < rows.length; i += 400) {
      final batch = _db.batch();
      for (final (:row, :coords) in rows.skip(i).take(400)) {
        batch.set(_clients.doc(), {
          'name': row.name,
          'nameKey': Client.normalizeName(row.name),
          'aliases': const <String>[],
          'vat': row.vat,
          'city': row.area,
          'address': '',
          'phone': '',
          'mobile': '',
          'tags': '',
          'odooSalesperson': row.salesperson,
          'notes': row.note,
          'googlePin': row.link,
          'lat': coords?.lat,
          'lng': coords?.lng,
          'assignedTo': uidBySalesperson[normalizeSalesperson(row.salesperson)],
          'category': defaultCategory,
          'lastVisitAt': null,
          'source': 'import',
          'importBatchId': batchRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    await batchRef.set({
      'fileName': fileName,
      'importedBy': importedBy,
      'added': rows.length,
      'updated': 0,
      'unchanged': 0,
      'withoutLocation': rows.where((r) => r.coords == null).length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Writes the plan in batches (Firestore allows 500 writes per batch) and
  /// records an `import_batches` entry for the dashboard.
  Future<void> commitImport(
    ImportPlan plan, {
    required String fileName,
    required String importedBy,
    required String defaultCategory,
  }) async {
    final batchRef = _db.collection('import_batches').doc();
    final ops = <void Function(WriteBatch)>[
      for (final w in plan.creates)
        (b) => b.set(_clients.doc(), {
              ...w.data,
              if (!w.data.containsKey('category')) 'category': defaultCategory,
              'importBatchId': batchRef.id,
              'createdAt': FieldValue.serverTimestamp(),
            }),
      for (final w in plan.updates)
        (b) => b.update(_clients.doc(w.existingId), {
              ...w.data,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
    ];
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(batch);
      }
      await batch.commit();
    }
    await batchRef.set({
      'fileName': fileName,
      'importedBy': importedBy,
      'added': plan.creates.length,
      'updated': plan.updates.length,
      'unchanged': plan.unchanged,
      'withoutLocation': plan.newWithoutPin.length + plan.newWithUnreadablePin.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
