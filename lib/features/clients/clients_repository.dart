import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../import/import_plan.dart';
import '../import/location_import.dart';
import '../notifications/notifications.dart';
import '../plan/plan_task.dart';
import 'client.dart';
import 'duplicates.dart';
import 'merge.dart';
import 'transfer.dart';

/// Every client the signed-in user may read (all for KAM/managers, own for
/// sales execs), hidden ones included: for the client page, imports and
/// duplicate checks.
final allClientsProvider = StreamProvider<List<Client>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('clients');
  if (!me.role.isSupervisor) query = query.where('assignedTo', isEqualTo: me.id);
  return query.snapshots().map(
        (s) => s.docs.map(Client.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// The clients used everywhere else (lists, map, plans, statistics): hidden
/// ones left out.
final clientsProvider = Provider<AsyncValue<List<Client>>>(
  (ref) => ref.watch(allClientsProvider).whenData((list) => list.where((c) => !c.hidden).toList()),
);

/// Ids of hidden clients, to leave their visits and plan items out of statistics.
final hiddenClientIdsProvider = Provider<Set<String>>((ref) => {
      for (final c in ref.watch(allClientsProvider).value ?? const <Client>[])
        if (c.hidden) c.id,
    });

/// Sales executive filter shared by the client list and map.
/// null = everyone, [unassignedFilter] = clients without a sales executive.
final salesFilterProvider = NotifierProvider<SalesFilter, String?>(SalesFilter.new);
const unassignedFilter = '_unassigned';

bool matchesSalesFilter(Client c, String? filter) =>
    filter == null || (filter == unassignedFilter ? c.assignedTo == null : c.assignedTo == filter);

class SalesFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final filteredClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final filter = ref.watch(salesFilterProvider);
  return ref.watch(clientsProvider).whenData((list) => list.where((c) => matchesSalesFilter(c, filter)).toList());
});

/// Hidden clients under the sales filter, for the client list's "Hidden" chip.
final filteredHiddenClientsProvider = Provider<List<Client>>((ref) {
  final filter = ref.watch(salesFilterProvider);
  return [
    for (final c in ref.watch(allClientsProvider).value ?? const <Client>[])
      if (c.hidden && matchesSalesFilter(c, filter)) c,
  ];
});

/// Possible duplicates among the visible clients (KAM / managers). With a
/// salesperson filter, groups with at least one of their clients.
final duplicateGroupsProvider = Provider<List<DuplicateGroup>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.role.isSupervisor) return const [];
  final groups = ref.watch(_allDuplicateGroupsProvider);
  final filter = ref.watch(salesFilterProvider);
  return [
    for (final g in groups)
      if (g.clients.any((c) => matchesSalesFilter(c, filter))) g,
  ];
});

final _allDuplicateGroupsProvider =
    Provider<List<DuplicateGroup>>((ref) => findDuplicates(ref.watch(clientsProvider).value ?? const []));

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

  /// KAM / managers hide a client from lists and statistics, or show it again.
  Future<void> setHidden(String clientId, {required bool hidden, required String by}) =>
      setHiddenMany([clientId], hidden: hidden, by: by);

  /// [setHidden] for several clients, in batches (500 writes per batch max).
  Future<void> setHiddenMany(List<String> clientIds, {required bool hidden, required String by}) async {
    for (var i = 0; i < clientIds.length; i += 400) {
      final batch = _db.batch();
      for (final id in clientIds.skip(i).take(400)) {
        batch.update(_clients.doc(id), {
          'hidden': hidden,
          'hiddenBy': hidden ? by : null,
          'hiddenAt': hidden ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Marks [clients] as different customers, so they stop showing as
  /// possible duplicates of each other.
  Future<void> markNotDuplicates(List<Client> clients) async {
    final batch = _db.batch();
    for (final c in clients) {
      batch.update(_clients.doc(c.id), {
        'notDuplicates': FieldValue.arrayUnion([for (final o in clients) if (o.id != c.id) o.id]),
      });
    }
    await batch.commit();
  }

  /// Sales manager / GM: merges [others] into [keep]. Their visits, plan
  /// items and attachments move to [keep] (files stay where they are; the
  /// download links keep working), [keep] gets their details (see
  /// [mergeUpdate]) and they are deleted.
  Future<void> merge(Client keep, List<Client> others, {required String byId}) async {
    final ops = <void Function(WriteBatch)>[];
    for (final o in others) {
      for (final collection in ['visits', 'tasks']) {
        final s = await _db.collection(collection).where('clientId', isEqualTo: o.id).get();
        for (final d in s.docs) {
          ops.add((b) => b.update(d.reference, {'clientId': keep.id, 'clientName': keep.name}));
        }
      }
      final files = await _clients.doc(o.id).collection('attachments').get();
      for (final d in files.docs) {
        ops.add((b) => b.set(_clients.doc(keep.id).collection('attachments').doc(d.id), d.data()));
        ops.add((b) => b.delete(d.reference));
      }
    }
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(batch);
      }
      await batch.commit();
    }
    // Last, so a failure above leaves both clients in place.
    final batch = _db.batch();
    batch.update(_clients.doc(keep.id), {
      ...mergeUpdate(keep, others, byId: byId, at: DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final o in others) {
      batch.delete(_clients.doc(o.id));
    }
    await batch.commit();
  }

  /// Moves [clients] to the sales executive [toId] (null = unassigned):
  /// logs the move on each client, removes the previous owner's open plan
  /// items for them from today on, and notifies both people. Clients already
  /// with [toId] are skipped; returns how many were moved.
  Future<int> transfer(List<Client> clients, {required String? toId, required AppUser by}) async {
    final moved = clients.where((c) => c.assignedTo != toId).toList();
    if (moved.isEmpty) return 0;
    final now = DateTime.now();
    for (var i = 0; i < moved.length; i += 400) {
      final batch = _db.batch();
      for (final c in moved.skip(i).take(400)) {
        final entry = ClientTransfer(fromId: c.assignedTo, toId: toId, byId: by.id, at: now);
        batch.update(_clients.doc(c.id), {
          'assignedTo': toId,
          'transfers': FieldValue.arrayUnion([entry.toMap()]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    // Open plan items of the previous owners (whereIn takes 30 values).
    final previousOwner = {for (final c in moved) c.id: c.assignedTo};
    final tasks = <PlanTask>[];
    final ids = previousOwner.keys.toList();
    for (var i = 0; i < ids.length; i += 30) {
      final s = await _db.collection('tasks').where('clientId', whereIn: ids.skip(i).take(30).toList()).get();
      tasks.addAll(s.docs.map(PlanTask.fromDoc));
    }
    final drop = planItemsToDrop(tasks, previousOwner, dayKey(now));
    for (var i = 0; i < drop.length; i += 400) {
      final batch = _db.batch();
      for (final t in drop.skip(i).take(400)) {
        batch.delete(_db.collection('tasks').doc(t.id));
      }
      await batch.commit();
    }

    if (toId != null) {
      await sendNotifications(
        toIds: [toId],
        type: NotificationType.clientsTransferredIn,
        fromId: by.id,
        ownerId: '',
        date: '',
        count: moved.length,
      );
    }
    final countByOwner = <String, int>{};
    for (final owner in previousOwner.values.nonNulls) {
      countByOwner[owner] = (countByOwner[owner] ?? 0) + 1;
    }
    for (final MapEntry(key: owner, value: count) in countByOwner.entries) {
      await sendNotifications(
        toIds: [owner],
        type: NotificationType.clientsTransferredOut,
        fromId: by.id,
        ownerId: toId ?? '',
        date: '',
        count: count,
      );
    }
    return moved.length;
  }

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
