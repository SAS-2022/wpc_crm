import 'dart:math' as math;

import '../clients/client.dart';
import '../home/stats.dart';
import '../visits/visit.dart';
import 'report.dart';
import 'report_sections.dart';
import 'routing_pace.dart';

// What Reports adds to each person's row for the end-of-month report (user
// request 2026-10-22): days in the field, client types visited (client
// tags), first visits vs re-visits, new clients, the average day, whether
// the target was reached, and a ranking score. Each person's report is also
// downloaded as a PDF (report_pdf.dart).

/// What the ranking score is made of; each part gives up to its weight in
/// points, 100 in all.
enum ScorePart { target, efficiency, clients, newClients, firstVisits }

const scoreWeights = {
  ScorePart.target: 35,
  ScorePart.efficiency: 25,
  ScorePart.clients: 15,
  ScorePart.newClients: 15,
  ScorePart.firstVisits: 10,
};

/// Visits and distinct clients of one client tag.
typedef TagCount = ({int clients, int visits});

/// The average of a person's days in the field that have a GPS timeline.
class AverageDay {
  const AverageDay({
    required this.days,
    required this.split,
    required this.drivingKm,
    this.firstClientMin,
    this.lastClientMin,
  });

  final int days;

  /// Minutes a day per kind of time.
  final TimeSplit split;
  final double drivingKm;

  /// Arrival at the first client / departure from the last, in minutes after midnight.
  final int? firstClientMin;
  final int? lastClientMin;
}

/// One person's row of the team table with the rank.
class RankedPerson {
  const RankedPerson({
    required this.report,
    required this.routing,
    required this.workDays,
    required this.visitsByClient,
    required this.firstClients,
    required this.revisitedClients,
    required this.byTag,
    required this.newClients,
    required this.scoreParts,
    required this.rank,
  });

  /// Visits, calls, target, coverage, plan … for the period.
  final PersonReport report;

  /// Their routing days and timelines; null when not in the routing report.
  final RoutingRow? routing;

  /// Days with at least one visit.
  final int workDays;

  /// Client id → their visits there in the period (calls not counted).
  final Map<String, int> visitsByClient;

  /// Clients nobody had visited before, first visited in the period by this
  /// person; and the clients they visited that had been visited before.
  final List<String> firstClients;
  final List<String> revisitedClients;

  /// Tag id ('' = no tag) → clients visited and visits. A client with two
  /// tags counts under both.
  final Map<String, TagCount> byTag;

  /// Clients added in the app by them or imported for them in the period.
  final int newClients;

  /// Points per part of the score.
  final Map<ScorePart, double> scoreParts;
  double get score => scoreParts.values.fold(0.0, (s, p) => s + p);

  /// 1 = best.
  final int rank;

  double? get targetShare => report.target > 0 ? report.contacts / report.target : null;
  bool get targetAchieved => report.target > 0 && report.contacts >= report.target.round();
  double? get efficiency => routing?.averageRate;
  AverageDay? get averageDay => routing == null ? null : averageDayOf(routing!.timelines);
}

/// Ranks [reports] (the whole team, so a person's rank doesn't depend on
/// who is shown). [visits]: the period's visits and calls of everyone (for
/// who visited a client first), hidden clients left out. [visitedBefore]:
/// clients with a visit before the period. [clients]: every client by id,
/// for tags. [newClientsFrom]: the clients new clients are counted from.
List<RankedPerson> rankPeople({
  required List<PersonReport> reports,
  required StatsRange range,
  required List<Visit> visits,
  required Set<String> visitedBefore,
  required Map<String, Client> clients,
  required List<Client> newClientsFrom,
  required RoutingReport routing,
}) {
  final inRange = visits.where((v) => !v.isCall && v.checkedInAt != null && range.contains(v.checkedInAt!)).toList()
    ..sort((a, b) => a.checkedInAt!.compareTo(b.checkedInAt!));
  // Who visited each client first in the period.
  final firstVisitor = <String, String>{};
  for (final v in inRange) {
    firstVisitor.putIfAbsent(v.clientId, () => v.salesExecId);
  }
  final routingRows = {for (final r in routing.rows) r.user.id: r};
  String nameOf(String id) => clients[id]?.name.toLowerCase() ?? '';

  final counts = [
    for (final report in reports)
      () {
        final uid = report.user.id;
        final mine = inRange.where((v) => v.salesExecId == uid).toList();
        final byClient = <String, int>{};
        for (final v in mine) {
          byClient[v.clientId] = (byClient[v.clientId] ?? 0) + 1;
        }
        final first = [
          for (final id in byClient.keys)
            if (!visitedBefore.contains(id) && firstVisitor[id] == uid) id,
        ]..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
        final revisited = [
          for (final id in byClient.keys)
            if (!first.contains(id)) id,
        ]..sort((a, b) => nameOf(a).compareTo(nameOf(b)));

        final tagClients = <String, Set<String>>{}, tagVisits = <String, int>{};
        for (final v in mine) {
          final tags = clients[v.clientId]?.tagIds ?? const <String>[];
          for (final t in tags.isEmpty ? const [''] : tags) {
            (tagClients[t] ??= {}).add(v.clientId);
            tagVisits[t] = (tagVisits[t] ?? 0) + 1;
          }
        }
        return _Counts(
          report: report,
          routing: routingRows[uid],
          workDays: {for (final v in mine) DateTime(v.checkedInAt!.year, v.checkedInAt!.month, v.checkedInAt!.day)}.length,
          byClient: byClient,
          first: first,
          revisited: revisited,
          byTag: {for (final t in tagClients.keys) t: (clients: tagClients[t]!.length, visits: tagVisits[t]!)},
          newClients: newClientsReport(clients: newClientsFrom, people: {uid}, range: range).clients.length,
        );
      }(),
  ];

  // Parts that compare people give full marks to the team's best.
  int best(int Function(_Counts) f) => counts.fold(0, (m, c) => math.max(m, f(c)));
  final bestContacts = best((c) => c.report.contacts);
  final bestClients = best((c) => c.report.clientsVisited);
  final bestNew = best((c) => c.newClients);
  final bestFirst = best((c) => c.first.length);
  double share(int n, int top) => top == 0 ? 0 : n / top;
  Map<ScorePart, double> partsOf(_Counts c) {
    final target = c.report.target;
    final shares = {
      // Without a target: compared with the busiest person.
      ScorePart.target: target > 0 ? math.min(1.0, c.report.contacts / target) : share(c.report.contacts, bestContacts),
      ScorePart.efficiency: c.routing?.averageRate ?? 0.0,
      ScorePart.clients: share(c.report.clientsVisited, bestClients),
      ScorePart.newClients: share(c.newClients, bestNew),
      ScorePart.firstVisits: share(c.first.length, bestFirst),
    };
    return {for (final p in ScorePart.values) p: scoreWeights[p]! * shares[p]!};
  }

  double total(Map<ScorePart, double> p) => p.values.fold(0.0, (s, x) => s + x);
  final scored = [for (final c in counts) (c: c, parts: partsOf(c))]..sort((a, b) {
      final s = total(b.parts).compareTo(total(a.parts));
      if (s != 0) return s;
      final v = b.c.report.contacts.compareTo(a.c.report.contacts);
      return v != 0 ? v : a.c.report.user.name.compareTo(b.c.report.user.name);
    });
  // Equal scores (to one decimal) share a rank.
  final ranks = <int>[];
  for (final (i, s) in scored.indexed) {
    final tie = i > 0 && (total(s.parts) * 10).round() == (total(scored[i - 1].parts) * 10).round();
    ranks.add(tie ? ranks.last : i + 1);
  }

  return [
    for (final (i, s) in scored.indexed)
      RankedPerson(
        report: s.c.report,
        routing: s.c.routing,
        workDays: s.c.workDays,
        visitsByClient: s.c.byClient,
        firstClients: s.c.first,
        revisitedClients: s.c.revisited,
        byTag: s.c.byTag,
        newClients: s.c.newClients,
        scoreParts: s.parts,
        rank: ranks[i],
      ),
  ];
}

/// A person's counts before scoring.
class _Counts {
  const _Counts({
    required this.report,
    required this.routing,
    required this.workDays,
    required this.byClient,
    required this.first,
    required this.revisited,
    required this.byTag,
    required this.newClients,
  });

  final PersonReport report;
  final RoutingRow? routing;
  final int workDays;
  final Map<String, int> byClient;
  final List<String> first;
  final List<String> revisited;
  final Map<String, TagCount> byTag;
  final int newClients;
}

/// The average of the days with at least one client stay; null without one.
AverageDay? averageDayOf(List<DayTimeline> timelines) {
  final days = timelines.where((t) => t.clientStays.isNotEmpty).toList();
  if (days.isEmpty) return null;
  final total = addSplits(days.map((t) => t.minutes));
  int? meanMinute(Iterable<DateTime?> times) {
    final m = [for (final t in times) if (t != null) t.hour * 60 + t.minute];
    return m.isEmpty ? null : (m.fold(0, (s, x) => s + x) / m.length).round();
  }

  return AverageDay(
    days: days.length,
    split: {for (final k in TimeKind.values) k: ((total[k] ?? 0) / days.length).round()},
    drivingKm: days.fold(0.0, (s, t) => s + t.drivingKm) / days.length,
    firstClientMin: meanMinute(days.map((t) => t.firstClientAt)),
    lastClientMin: meanMinute(days.map((t) => t.lastClientAt)),
  );
}

/// "08:45" from minutes after midnight.
String clockOf(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
