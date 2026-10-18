import '../../core/app_user.dart';
import '../clients/client.dart';
import '../clients/given_items.dart';
import '../home/stats.dart';
import '../plan/route_order.dart';
import '../visits/visit.dart';

// Reports: new clients, routing efficiency and catalog distribution for a
// period and a group of people (user request 2026-10-18).

/// Clients added in the period by or for [people].
class NewClientsReport {
  const NewClientsReport({required this.clients, required this.addedBy, required this.manual, required this.imported});

  /// Newest first.
  final List<Client> clients;

  /// Person id → clients they added in the app.
  final Map<String, int> addedBy;
  final int manual;
  final int imported;
}

/// A client counts when one of [people] added it in the app, or it was
/// imported and belongs to one of them; with [includeUnowned] (the whole
/// team view of a manager) imported clients that belong to nobody too.
NewClientsReport newClientsReport({
  required List<Client> clients,
  required Set<String> people,
  required StatsRange range,
  bool includeUnowned = false,
}) {
  final added = clients.where((c) {
    if (c.createdAt == null || !range.contains(c.createdAt!)) return false;
    if (c.source == 'manual') return people.contains(c.createdBy) || people.contains(c.assignedTo);
    return people.contains(c.assignedTo) || (includeUnowned && c.assignedTo == null);
  }).toList()
    ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  final by = <String, int>{};
  for (final c in added) {
    if (c.source == 'manual' && people.contains(c.createdBy)) by[c.createdBy] = (by[c.createdBy] ?? 0) + 1;
  }
  final manual = added.where((c) => c.source == 'manual').length;
  return NewClientsReport(clients: added, addedBy: by, manual: manual, imported: added.length - manual);
}

/// One day of one person with at least two visits.
class RoutingDay {
  const RoutingDay({required this.user, required this.day, required this.visits, required this.efficiency});

  final AppUser user;
  final DateTime day;
  final int visits;
  final DayEfficiency efficiency;

  /// Straight-line metres more than the shortest order between the visits.
  double get extraMeters => (efficiency.takenMeters - efficiency.shortestMeters).clamp(0, double.infinity);
}

/// A person's routing over the period.
class RoutingRow {
  const RoutingRow({required this.user, required this.days});

  final AppUser user;
  final List<RoutingDay> days;

  /// Mean daily efficiency; null without a day of two visits.
  double? get averageRate => days.isEmpty ? null : days.fold(0.0, (s, d) => s + d.efficiency.rate) / days.length;
  int get bestOrderDays => days.where((d) => d.efficiency.bestOrder).length;
  double get extraMeters => days.fold(0.0, (s, d) => s + d.extraMeters);
  double get visitsPerDay => days.isEmpty ? 0 : days.fold(0, (s, d) => s + d.visits) / days.length;
  Duration get needed => days.fold(Duration.zero, (s, d) => s + d.efficiency.needed);
  Duration get took => days.fold(Duration.zero, (s, d) => s + d.efficiency.took);
}

/// Each person's days in the period (visits, not calls, with a position:
/// the check-in, else the client's location).
List<RoutingRow> routingReport({
  required List<AppUser> people,
  required List<Visit> visits,
  required Map<String, Client> clients,
  required StatsRange range,
}) {
  Stop? place(Visit v) {
    if (v.checkInLat != null && v.checkInLng != null) return (v.checkInLat!, v.checkInLng!);
    final c = clients[v.clientId];
    return c != null && c.hasLocation ? (c.lat!, c.lng!) : null;
  }

  return [
    for (final u in people)
      () {
        final byDay = <DateTime, List<({DateTime at, Stop place})>>{};
        for (final v in visits) {
          if (v.isCall || v.salesExecId != u.id || v.checkedInAt == null || !range.contains(v.checkedInAt!)) continue;
          final p = place(v);
          if (p == null) continue;
          final t = v.checkedInAt!;
          (byDay[DateTime(t.year, t.month, t.day)] ??= []).add((at: t, place: p));
        }
        final days = [
          for (final MapEntry(key: day, value: list) in byDay.entries)
            if (dayEfficiency(list) case final e?) RoutingDay(user: u, day: day, visits: list.length, efficiency: e),
        ]..sort((a, b) => a.day.compareTo(b.day));
        return RoutingRow(user: u, days: days);
      }(),
  ];
}

/// Catalogs / stands one person handed over in the period.
class CatalogRow {
  const CatalogRow({required this.user, required this.byItem, required this.clients});

  final AppUser user;
  final Map<GivenItem, int> byItem;

  /// Distinct clients who got something.
  final int clients;

  int get total => byItem.values.fold(0, (s, n) => s + n);
}

class CatalogReport {
  const CatalogReport({required this.rows, required this.dueNow, required this.neverGiven});

  final List<CatalogRow> rows;

  /// Clients of the people due for a new one / who never got one, per item.
  final Map<GivenItem, int> dueNow;
  final Map<GivenItem, int> neverGiven;
}

/// From the clients' hand-over logs (visits and recorded entries).
CatalogReport catalogReport({
  required List<AppUser> people,
  required List<Client> clients,
  required StatsRange range,
  required GivenItemRules rules,
  required DateTime now,
}) {
  final ids = {for (final u in people) u.id};
  final rows = [
    for (final u in people)
      () {
        final byItem = <GivenItem, int>{};
        final reached = <String>{};
        for (final c in clients) {
          for (final e in c.givenLog) {
            if (e.byId != u.id || !range.contains(e.at)) continue;
            byItem[e.item] = (byItem[e.item] ?? 0) + e.qty;
            reached.add(c.id);
          }
        }
        return CatalogRow(user: u, byItem: byItem, clients: reached.length);
      }(),
  ];
  final owned = clients.where((c) => ids.contains(c.assignedTo));
  return CatalogReport(
    rows: rows,
    dueNow: {
      for (final item in GivenItem.values)
        item: owned.where((c) => givenStatus(c.given[item], item, rules, now) == GivenStatus.due).length,
    },
    neverGiven: {
      for (final item in GivenItem.values) item: owned.where((c) => c.given[item] == null).length,
    },
  );
}
