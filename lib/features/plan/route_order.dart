import 'dart:math' as math;

import '../clients/client.dart';
import 'plan_task.dart';

/// A stop as (lat, lng).
typedef Stop = (double, double);

/// Straight-line metres between two stops.
double stopMeters(Stop a, Stop b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.$1 - a.$1);
  final dLng = rad(b.$2 - a.$2);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.$1)) * math.cos(rad(b.$1)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// Metres along [stops] in the given order.
double pathMeters(List<Stop> stops) {
  var m = 0.0;
  for (var i = 1; i < stops.length; i++) {
    m += stopMeters(stops[i - 1], stops[i]);
  }
  return m;
}

/// The order (indexes into [stops]) that visits every stop with the shortest
/// straight-line path, starting at any stop and ending at any stop. Nearest
/// neighbour from every start, then 2-opt; exact enough for a day's plan
/// (up to a few dozen stops). Same input → same order.
List<int> shortestOrder(List<Stop> stops) {
  final n = stops.length;
  if (n < 3) return [for (var i = 0; i < n; i++) i];
  final d = [
    for (final a in stops) [for (final b in stops) stopMeters(a, b)],
  ];
  double length(List<int> o) {
    var m = 0.0;
    for (var i = 1; i < o.length; i++) {
      m += d[o[i - 1]][o[i]];
    }
    return m;
  }

  List<int>? best;
  var bestLength = double.infinity;
  for (var start = 0; start < n; start++) {
    final order = [start];
    final left = {for (var i = 0; i < n; i++) i}..remove(start);
    while (left.isNotEmpty) {
      final last = order.last;
      final next = left.reduce((a, b) => d[last][b] < d[last][a] ? b : a);
      order.add(next);
      left.remove(next);
    }
    // 2-opt for an open path: reverse order[i..j] while it shortens the path.
    var improved = true;
    while (improved) {
      improved = false;
      for (var i = 0; i < n - 1; i++) {
        for (var j = i + 1; j < n; j++) {
          final before = (i > 0 ? d[order[i - 1]][order[i]] : 0) + (j < n - 1 ? d[order[j]][order[j + 1]] : 0);
          final after = (i > 0 ? d[order[i - 1]][order[j]] : 0) + (j < n - 1 ? d[order[i]][order[j + 1]] : 0);
          if (after < before - 0.01) {
            final mid = order.sublist(i, j + 1).reversed.toList();
            order.replaceRange(i, j + 1, mid);
            improved = true;
          }
        }
      }
    }
    final l = length(order);
    if (l < bestLength - 0.01) {
      bestLength = l;
      best = order;
    }
  }
  return best!;
}

/// Time allowed per client visit (user: a visit takes 15–30 minutes; the
/// maximum is allowed before time counts as lost).
const visitAllowance = Duration(minutes: 30);

/// Driving estimate without paid road routing: straight line × [roadFactor]
/// at [travelKmh].
const roadFactor = 1.4;
const travelKmh = 40.0;

Duration travelTime(double straightMeters) =>
    Duration(seconds: (straightMeters * roadFactor / (travelKmh * 1000 / 3600)).round());

/// How well a day's visits used the time between the first and last check-in.
class DayEfficiency {
  const DayEfficiency({
    required this.took,
    required this.needed,
    required this.takenMeters,
    required this.shortestMeters,
    this.measured = false,
  });

  /// From the GPS timeline (first client arrival to last departure, minus
  /// lunch and office) rather than from the check-in times.
  final bool measured;

  /// First to last check-in.
  final Duration took;

  /// Shortest route through the same clients + [visitAllowance] for every
  /// visit but the last.
  final Duration needed;

  /// Straight-line metres between the visits in the order made / in the
  /// shortest order.
  final double takenMeters;
  final double shortestMeters;

  /// needed / took, at most 1.
  double get rate => took.inSeconds <= 0 ? 1 : math.min(1, needed.inSeconds / took.inSeconds);

  /// Whether the visits were made in the shortest order (within 5 %).
  bool get bestOrder => takenMeters <= shortestMeters * 1.05 + 50;
}

/// [visits]: check-in time and position, in any order. Null with fewer than
/// two visits.
DayEfficiency? dayEfficiency(List<({DateTime at, Stop place})> visits) {
  if (visits.length < 2) return null;
  final sorted = [...visits]..sort((a, b) => a.at.compareTo(b.at));
  final taken = [for (final v in sorted) v.place];
  final order = shortestOrder(taken);
  final shortest = pathMeters([for (final i in order) taken[i]]);
  return DayEfficiency(
    took: sorted.last.at.difference(sorted.first.at),
    needed: travelTime(shortest) + visitAllowance * (sorted.length - 1),
    takenMeters: pathMeters(taken),
    shortestMeters: shortest,
  );
}

/// Plan numbering (user decision 2026-10-18): the day's client visits (not
/// rejected, client with a location) numbered in the shortest order, done
/// ones included so the numbers stay put during the day. Task id → 1, 2, …
Map<String, int> planStopNumbers(List<PlanTask> tasks, Map<String, Client> clients) {
  final stops = [
    for (final t in tasks)
      if (t.isVisit && t.approval != TaskApproval.rejected && (clients[t.clientId]?.hasLocation ?? false)) t,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final order = shortestOrder([for (final t in stops) (clients[t.clientId]!.lat!, clients[t.clientId]!.lng!)]);
  return {for (final (n, i) in order.indexed) stops[i].id: n + 1};
}

/// [tasks] with the numbered stops first, in route order; the rest keep
/// their order after them.
List<PlanTask> inRouteOrder(List<PlanTask> tasks, Map<String, int> numbers) {
  final numbered = tasks.where((t) => numbers.containsKey(t.id)).toList()
    ..sort((a, b) => numbers[a.id]!.compareTo(numbers[b.id]!));
  return [...numbered, ...tasks.where((t) => !numbers.containsKey(t.id))];
}
