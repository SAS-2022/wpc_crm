import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import 'client.dart';
import 'transfer.dart';

/// "Also visited by" (2026-11-21, user): a KAM / sales manager asks a sales
/// exec (or KAM) to visit some locations of a client that isn't theirs, e.g.
/// the Dammam showroom of a Riyadh company. The owner stays the same; the
/// visitor sees the client with only those locations, checks in, logs calls
/// and records catalogs there; the visit counts for the visitor and the
/// owner is told. Stored on the client as `visitAssignments` [{uid,
/// locationIds, byId, at}] + `visitorIds` (the uids, for rules and queries).
class VisitAssignment {
  const VisitAssignment({required this.uid, this.locationIds = const [], this.byId = '', this.at});

  factory VisitAssignment.fromMap(Map<dynamic, dynamic> m) => VisitAssignment(
        uid: m['uid'] as String? ?? '',
        locationIds: [for (final id in m['locationIds'] as List? ?? const []) if (id is String) id],
        byId: m['byId'] as String? ?? '',
        at: (m['at'] as Timestamp?)?.toDate(),
      );

  final String uid;

  /// Client location ids ([ClientLocation.mainId] = the main one); empty =
  /// every location.
  final List<String> locationIds;
  final String byId;
  final DateTime? at;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'locationIds': locationIds,
        'byId': byId,
        // Inside an array: no server timestamp allowed.
        'at': Timestamp.fromDate(at ?? DateTime.now()),
      };
}

List<VisitAssignment> parseVisitAssignments(Object? raw) => [
      for (final m in raw as List? ?? const [])
        if (m is Map && (m['uid'] as String? ?? '').isNotEmpty) VisitAssignment.fromMap(m),
    ];

/// The Firestore fields for [list] (whole list; a person once).
Map<String, dynamic> visitAssignmentsUpdate(List<VisitAssignment> list) {
  final byUid = {for (final a in list) a.uid: a};
  return {
    'visitAssignments': [for (final a in byUid.values) a.toMap()],
    'visitorIds': byUid.keys.toList(),
  };
}

/// [uid]'s assignment on [c]; null when they aren't asked to visit it.
VisitAssignment? assignmentOf(Client c, String uid) => c.visitAssignments.where((a) => a.uid == uid).firstOrNull;

/// [uid] visits [c] for its owner (it isn't theirs).
bool isVisitorOf(Client c, String? uid) => uid != null && c.assignedTo != uid && assignmentOf(c, uid) != null;

/// The locations of [c] that [uid] is to visit: all for the owner, the chosen
/// ones for a visitor (all when none were chosen). Ids that no longer exist
/// are skipped.
List<ClientLocation> locationsFor(Client c, String uid) {
  final a = isVisitorOf(c, uid) ? assignmentOf(c, uid) : null;
  if (a == null || a.locationIds.isEmpty) return c.locations;
  return [for (final l in c.locations) if (a.locationIds.contains(l.id)) l];
}

/// Whether [me] may add / change visitors of [c]: whoever may move the
/// client (sales manager / GM any; a KAM their own, their team's or
/// unassigned ones).
bool canAssignVisitors(AppUser me, Client c, Map<String, AppUser> users) => canTransferFrom(me, c.assignedTo, users);

/// People [me] may ask to visit [c]: the transfer targets (SM / GM: every
/// active sales exec and KAM; a KAM: their team and themselves), not the owner.
List<AppUser> visitorCandidates(AppUser me, Client c, List<AppUser> users) => [
      for (final u in transferTargets(me, users))
        if (u.id != c.assignedTo) u,
    ];

/// The other clients linked with [c] ("Linked clients": its main company,
/// that one's main company, … and every branch below the top one), sorted
/// by name; empty when it isn't linked (2026-11-21, user: assign a visitor
/// to the related showrooms / companies from one place).
List<Client> linkedGroupOf(Client c, List<Client> all) {
  final byId = {for (final x in all) x.id: x};
  var top = c;
  final seen = {c.id};
  while (top.parentId != null && byId[top.parentId] != null && seen.add(top.parentId!)) {
    top = byId[top.parentId]!;
  }
  final children = <String, List<Client>>{};
  for (final x in all) {
    if (x.parentId != null && x.parentId != x.id) (children[x.parentId!] ??= []).add(x);
  }
  final group = <String, Client>{top.id: top};
  void walk(String id) {
    for (final b in children[id] ?? const <Client>[]) {
      if (!group.containsKey(b.id)) {
        group[b.id] = b;
        walk(b.id);
      }
    }
  }

  walk(top.id);
  group.remove(c.id);
  return group.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// [c]'s assignments after giving [uid] [locationIds] (null = take them off).
List<VisitAssignment> withVisitor(Client c, String uid, List<String>? locationIds, {required String byId}) => [
      for (final a in c.visitAssignments)
        if (a.uid != uid) a,
      if (locationIds != null) VisitAssignment(uid: uid, locationIds: locationIds, byId: byId),
    ];

/// Salesperson filter (2026-11-21, user: the showrooms given to a person
/// must show when the map / list is filtered to them): [c] passes when its
/// owner is picked ([unassignedKey] for none) or one of its visitors is.
bool matchesOwnerOrVisitor(Client c, Set<String> filter, String unassignedKey) =>
    filter.isEmpty ||
    filter.contains(c.assignedTo ?? unassignedKey) ||
    c.visitAssignments.any((a) => filter.contains(a.uid));

/// The locations of [c] to show under the salesperson filter: all when the
/// owner (or nobody) is picked, else only those the picked visitors visit.
List<ClientLocation> locationsForFilter(Client c, Set<String> filter, String unassignedKey) {
  if (filter.isEmpty || filter.contains(c.assignedTo ?? unassignedKey)) return c.locations;
  final ids = <String>{};
  for (final a in c.visitAssignments) {
    if (!filter.contains(a.uid)) continue;
    if (a.locationIds.isEmpty) return c.locations;
    ids.addAll(a.locationIds);
  }
  return [for (final l in c.locations) if (ids.contains(l.id)) l];
}

/// Whose pin [l] is under the filter ("Colour by: Salesperson"): the owner,
/// unless only a visitor of that location is picked — then that visitor.
String? pinPersonFor(Client c, ClientLocation l, Set<String> filter, String unassignedKey) {
  if (filter.isEmpty || filter.contains(c.assignedTo ?? unassignedKey)) return c.assignedTo;
  for (final a in c.visitAssignments) {
    if (filter.contains(a.uid) && (a.locationIds.isEmpty || a.locationIds.contains(l.id))) return a.uid;
  }
  return c.assignedTo;
}
