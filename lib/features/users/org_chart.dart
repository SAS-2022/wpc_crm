import '../../core/app_user.dart';
import '../notifications/notifications.dart' show directManagersOf;

// Employee chart (user request 2026-11-11): the company as a tree, the GM on
// top, the people reporting to each manager under them. Built from the same
// rules as approvals and notices: a person's parent is their warehouse
// supervisor (`supervisorId`, drivers / workers) when set, else their first
// direct manager ([directManagersOf]: the chosen manager, else the role's
// default). People with several automatic managers (e.g. two sales
// managers) sit under the first; the others are listed as [OrgNode.alsoUnder].

class OrgNode {
  OrgNode(this.user);

  final AppUser user;
  final List<OrgNode> children = [];

  /// Other managers this person reports to (not drawn as lines).
  List<String> alsoUnder = const [];

  /// Everyone below, at any depth.
  int get teamSize => children.fold(0, (n, c) => n + 1 + c.teamSize);

  /// This node and everyone below.
  Iterable<OrgNode> get all sync* {
    yield this;
    for (final c in children) {
      yield* c.all;
    }
  }
}

/// Order among colleagues: managers first, by rank, then by name.
int _rank(AppUser u) => switch (u.role) {
      UserRole.gm => 0,
      UserRole.salesManager => 1,
      UserRole.factoryManager || UserRole.logisticsManager || UserRole.hr => 2,
      UserRole.kam || UserRole.warehouseSupervisor => 3,
      _ => u.isManager ? 3 : 5,
    };

/// The parent of [u] among [byId] (null = top of the chart).
String? orgParentOf(AppUser u, Map<String, AppUser> byId, List<AppUser> users) {
  final sup = byId[u.supervisorId];
  if (sup != null && sup.id != u.id) return sup.id;
  for (final id in directManagersOf(u, users)) {
    if (byId.containsKey(id) && id != u.id) return id;
  }
  return null;
}

/// The chart's top nodes (GMs, and anyone whose manager isn't in [users]):
/// active, approved people only. A chosen manager that would make a loop
/// (A under B under A) is ignored for the one that closes it.
List<OrgNode> buildOrgChart(List<AppUser> users) {
  final people = [for (final u in users) if (u.active && !u.isPendingApproval) u];
  final byId = {for (final u in people) u.id: u};
  final nodes = {for (final u in people) u.id: OrgNode(u)};
  final parent = <String, String?>{};
  for (final u in people) {
    parent[u.id] = orgParentOf(u, byId, people);
  }
  // Break loops: walk up from each person; a repeat means a loop.
  for (final u in people) {
    final seen = <String>{u.id};
    var p = parent[u.id];
    while (p != null) {
      if (!seen.add(p)) {
        parent[u.id] = null;
        break;
      }
      p = parent[p];
    }
  }
  final roots = <OrgNode>[];
  for (final u in people) {
    final node = nodes[u.id]!;
    final p = parent[u.id];
    node.alsoUnder = [
      for (final id in directManagersOf(u, people))
        if (id != p && byId.containsKey(id)) id,
    ];
    if (p == null) {
      roots.add(node);
    } else {
      nodes[p]!.children.add(node);
    }
  }
  int compare(OrgNode a, OrgNode b) {
    final r = _rank(a.user).compareTo(_rank(b.user));
    if (r != 0) return r;
    // Managers with bigger teams first, then by name.
    final t = b.teamSize.compareTo(a.teamSize);
    return t != 0 ? t : a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
  }

  void sortAll(List<OrgNode> list) {
    list.sort(compare);
    for (final n in list) {
      sortAll(n.children);
    }
  }

  sortAll(roots);
  return roots;
}

/// The part of the chart [me] sees: everything for HR / SM / GM, else the
/// branch under [me] (themselves on top).
List<OrgNode> orgChartFor(AppUser me, List<AppUser> users) {
  final roots = buildOrgChart(users);
  if (me.can.isAdmin || me.can.canManageHr) return roots;
  for (final r in roots) {
    for (final n in r.all) {
      if (n.user.id == me.id) return [n];
    }
  }
  return const [];
}
