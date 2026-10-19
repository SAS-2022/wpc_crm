import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/saving.dart';
import 'client.dart';

// Linked clients (user request 2026-10-19): a client (e.g. a showroom) links
// to its main company with `clients.parentId`; a main company can have any
// number of branches, and a branch can have branches of its own. KAM /
// managers link and unlink (no rules change: they may update any client).

/// A main company and its branches, recursively.
class ClientNode {
  const ClientNode(this.client, this.children);

  final Client client;
  final List<ClientNode> children;

  /// Branches at every level.
  int get size => children.fold(0, (n, c) => n + 1 + c.size);

  Iterable<Client> get all sync* {
    yield client;
    for (final c in children) {
      yield* c.all;
    }
  }
}

/// Branches of each client, by id, sorted by name. A parent that isn't in
/// [clients] (deleted, hidden, not readable) counts as no parent.
Map<String, List<Client>> branchesById(List<Client> clients) {
  final ids = {for (final c in clients) c.id};
  final out = <String, List<Client>>{};
  for (final c in clients) {
    final p = c.parentId;
    if (p != null && p != c.id && ids.contains(p)) (out[p] ??= []).add(c);
  }
  for (final list in out.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }
  return out;
}

/// Every client that has branches but no (known) main company, with its
/// tree. Clients without links are left out.
List<ClientNode> linkTrees(List<Client> clients) {
  final branches = branchesById(clients);
  final ids = {for (final c in clients) c.id};
  ClientNode build(Client c, Set<String> seen) => ClientNode(c, [
        for (final b in branches[c.id] ?? const <Client>[])
          if (seen.add(b.id)) build(b, seen),
      ]);
  return [
    for (final c in clients)
      if (branches.containsKey(c.id) && (c.parentId == null || !ids.contains(c.parentId))) build(c, {c.id}),
  ]..sort((a, b) => a.client.name.compareTo(b.client.name));
}

/// Ids of [id]'s branches at every level.
Set<String> descendantIds(String id, List<Client> clients) {
  final branches = branchesById(clients);
  final out = <String>{};
  void walk(String i) {
    for (final b in branches[i] ?? const <Client>[]) {
      if (out.add(b.id)) walk(b.id);
    }
  }

  walk(id);
  return out;
}

/// Whether [childId] may be linked under [parentId]: not itself and not one
/// of its own branches (no loops).
bool canLink(String childId, String parentId, List<Client> clients) =>
    childId != parentId && !descendantIds(childId, clients).contains(parentId);

CollectionReference<Map<String, dynamic>> get _clients => FirebaseFirestore.instance.collection('clients');

/// Links [childIds] under [parentId] (null = unlinks them).
Future<void> setClientParent(List<String> childIds, String? parentId) => saving(() async {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in childIds) {
        batch.update(_clients.doc(id), {'parentId': parentId, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    });

/// Before a client is deleted or merged away: its branches move to [to]
/// (its own main company, the kept client, or none).
Future<void> moveBranches(String fromId, String? to) async {
  final s = await _clients.where('parentId', isEqualTo: fromId).get();
  if (s.docs.isEmpty) return;
  final batch = FirebaseFirestore.instance.batch();
  for (final d in s.docs) {
    batch.update(d.reference, {'parentId': d.id == to ? null : to});
  }
  await batch.commit();
}
