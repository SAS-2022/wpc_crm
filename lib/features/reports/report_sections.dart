import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../clients/client.dart';
import '../clients/given_items.dart';
import '../home/stats.dart';
import '../plan/route_order.dart';
import '../visits/visit.dart';
import 'routing_pace.dart';

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
  const RoutingDay({required this.user, required this.day, required this.visits, required this.efficiency, this.timeline});

  final AppUser user;
  final DateTime day;
  final int visits;
  final DayEfficiency efficiency;

  /// The GPS timeline of the day, when the server built one.
  final DayTimeline? timeline;

  /// Straight-line metres more than the shortest order between the visits.
  double get extraMeters => (efficiency.takenMeters - efficiency.shortestMeters).clamp(0, double.infinity);
}

/// A person's routing over the period.
class RoutingRow {
  const RoutingRow({required this.user, required this.days, required this.pace, required this.timelines});

  final AppUser user;
  final List<RoutingDay> days;

  /// Their measured visit length, driving speed and road factor.
  final PersonPace pace;

  /// Every day in the period with a timeline (also days with one visit).
  final List<DayTimeline> timelines;

  /// Where the work days' time went, in minutes.
  TimeSplit get split => addSplits(timelines.map((t) => t.minutes));

  /// Mean daily efficiency; null without a day of two visits.
  double? get averageRate => days.isEmpty ? null : days.fold(0.0, (s, d) => s + d.efficiency.rate) / days.length;
  int get bestOrderDays => days.where((d) => d.efficiency.bestOrder).length;
  double get extraMeters => days.fold(0.0, (s, d) => s + d.extraMeters);
  double get visitsPerDay => days.isEmpty ? 0 : days.fold(0, (s, d) => s + d.visits) / days.length;
  Duration get needed => days.fold(Duration.zero, (s, d) => s + d.efficiency.needed);
  Duration get took => days.fold(Duration.zero, (s, d) => s + d.efficiency.took);
}

class RoutingReport {
  const RoutingReport({required this.rows, required this.pace});

  final List<RoutingRow> rows;

  /// The team benchmark the days were measured against.
  final TeamPace pace;
}

/// Each person's days in the period (visits, not calls, with a position:
/// the check-in, else the client's location), measured against the team
/// benchmark built from [benchmarkPeople]'s timelines (the whole team, also
/// when [people] is one person). [timelines]: by `uid_yyyy-MM-dd`.
RoutingReport routingReport({
  required List<AppUser> people,
  required List<Visit> visits,
  required Map<String, Client> clients,
  required StatsRange range,
  Map<String, DayTimeline> timelines = const {},
  List<AppUser>? benchmarkPeople,
}) {
  Stop? place(Visit v) {
    if (v.checkInLat != null && v.checkInLng != null) return (v.checkInLat!, v.checkInLng!);
    final c = clients[v.clientId];
    return c != null && c.hasLocation ? (c.lat!, c.lng!) : null;
  }

  final key = DateFormat('yyyy-MM-dd');
  // Each person's located visits by day.
  Map<DateTime, List<({DateTime at, Stop place})>> visitsByDay(AppUser u) {
    final byDay = <DateTime, List<({DateTime at, Stop place})>>{};
    for (final v in visits) {
      if (v.isCall || v.salesExecId != u.id || v.checkedInAt == null || !range.contains(v.checkedInAt!)) continue;
      final p = place(v);
      if (p == null) continue;
      final t = v.checkedInAt!;
      (byDay[DateTime(t.year, t.month, t.day)] ??= []).add((at: t, place: p));
    }
    return byDay;
  }

  List<DayTimeline> timelinesOf(AppUser u) => [
        for (final t in timelines.values)
          if (t.uid == u.id && range.contains(DateTime.tryParse(t.day)?.add(const Duration(hours: 12)) ?? DateTime(0))) t,
      ]..sort((a, b) => a.day.compareTo(b.day));

  PersonPace paceOf(AppUser u) {
    final straight = <String, double>{
      for (final MapEntry(key: day, value: list) in visitsByDay(u).entries)
        if (dayEfficiency(list) case final e?) key.format(day): e.takenMeters / 1000,
    };
    return personPace(u.id, timelinesOf(u), straight);
  }

  final paces = {for (final u in benchmarkPeople ?? people) u.id: paceOf(u)};
  final team = teamPace(paces.values.toList());
  return RoutingReport(
    pace: team,
    rows: [
      for (final u in people)
        () {
          final days = [
            for (final MapEntry(key: day, value: list) in visitsByDay(u).entries)
              if (paceEfficiency(list, pace: team, timeline: timelines['${u.id}_${key.format(day)}']) case final e?)
                RoutingDay(
                  user: u,
                  day: day,
                  visits: list.length,
                  efficiency: e,
                  timeline: timelines['${u.id}_${key.format(day)}'],
                ),
          ]..sort((a, b) => a.day.compareTo(b.day));
          return RoutingRow(user: u, days: days, pace: paces[u.id] ?? paceOf(u), timelines: timelinesOf(u));
        }(),
    ],
  );
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

/// From the clients' hand-over logs (visits and recorded entries) plus
/// [visits]' `given`: older app versions saved hand-overs only on the visit
/// (and the `clients.given` summary), never in the log. A visit whose
/// entries are in a log is counted once.
CatalogReport catalogReport({
  required List<AppUser> people,
  required List<Client> clients,
  List<Visit> visits = const [],
  required StatsRange range,
  required GivenItemRules rules,
  required DateTime now,
}) {
  final ids = {for (final u in people) u.id};
  final logged = {
    for (final c in clients)
      for (final e in c.givenLog) ?e.visitId,
  };
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
        for (final v in visits) {
          final at = v.checkedInAt;
          if (v.given.isEmpty || v.salesExecId != u.id || logged.contains(v.id)) continue;
          if (at == null || !range.contains(at)) continue;
          for (final MapEntry(key: item, value: qty) in v.given.entries) {
            byItem[item] = (byItem[item] ?? 0) + qty;
          }
          reached.add(v.clientId);
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
