import 'dart:math' as math;

import '../../core/app_user.dart';
import '../clients/client.dart';
import '../clients/visit_rules.dart';
import '../home/stats.dart';
import '../plan/plan_task.dart';
import '../visits/visit.dart';

/// One person's numbers for a period, a row of the team table.
class PersonReport {
  const PersonReport({
    required this.user,
    required this.visits,
    this.calls = 0,
    required this.target,
    required this.clientsVisited,
    required this.assigned,
    required this.assignedVisited,
    required this.onSchedule,
    required this.flagged,
    required this.withKam,
    required this.tasksApproved,
    required this.tasksDone,
  });

  final AppUser user;

  /// Visits made by this person in the period, and phone calls (they count
  /// toward the target too, shown as "visits + calls").
  final int visits;
  final int calls;

  int get contacts => visits + calls;

  /// Monthly target spread over the period; 0 = no target.
  final double target;

  /// Distinct clients this person visited or called.
  final int clientsVisited;

  /// Clients assigned to this person, and how many of them anyone visited or called.
  final int assigned;
  final int assignedVisited;

  /// Assigned clients that are green under the visit rules today.
  final int onSchedule;

  /// Visits far from the client or with fake GPS.
  final int flagged;

  /// Visits a KAM marked "I was there".
  final int withKam;
  final int tasksApproved;
  final int tasksDone;

  double? get coverage => assigned == 0 ? null : assignedVisited / assigned;
  double? get planCompletion => tasksApproved == 0 ? null : tasksDone / tasksApproved;
}

/// [visits] and [tasks] may hold more than the period; they are filtered here.
List<PersonReport> buildReports({
  required List<AppUser> people,
  required List<Client> clients,
  required List<Visit> visits,
  required List<PlanTask> tasks,
  required StatsRange range,
  required VisitRules rules,
  required DateTime now,
}) {
  final inRange = visits.where((v) => v.checkedInAt != null && range.contains(v.checkedInAt!)).toList();
  final visitedIds = {for (final v in inRange) v.clientId};
  return [
    for (final u in people)
      () {
        final mine = inRange.where((v) => v.salesExecId == u.id).toList();
        final assigned = clients.where((c) => c.assignedTo == u.id).toList();
        final approved = tasks
            .where((t) =>
                t.ownerId == u.id && t.approval == TaskApproval.approved && range.contains(DateTime.parse(t.date)))
            .toList();
        return PersonReport(
          user: u,
          visits: mine.where((v) => !v.isCall).length,
          calls: mine.where((v) => v.isCall).length,
          target: targetFor(u.monthlyTarget, range),
          clientsVisited: {for (final v in mine) v.clientId}.length,
          assigned: assigned.length,
          assignedVisited: assigned.where((c) => visitedIds.contains(c.id)).length,
          onSchedule: assigned.where((c) => visitStatus(c, rules, now) == VisitStatus.recent).length,
          flagged: mine.where((v) => v.isFlagged).length,
          withKam: mine.where((v) => v.kamId != null).length,
          tasksApproved: approved.length,
          tasksDone: approved.where((t) => t.done).length,
        );
      }(),
  ];
}

/// Clients of [ownerIds] nobody visited in the period, longest unvisited
/// first (never visited at the top).
List<Client> unvisitedClients({
  required List<Client> clients,
  required Set<String> ownerIds,
  required List<Visit> visits,
  required StatsRange range,
}) {
  final visited = {
    for (final v in visits)
      if (v.checkedInAt != null && range.contains(v.checkedInAt!)) v.clientId,
  };
  return clients.where((c) => ownerIds.contains(c.assignedTo) && !visited.contains(c.id)).toList()
    ..sort((a, b) {
      if (a.lastVisitAt == null || b.lastVisitAt == null) {
        if (a.lastVisitAt == b.lastVisitAt) return a.name.compareTo(b.name);
        return a.lastVisitAt == null ? -1 : 1;
      }
      return a.lastVisitAt!.compareTo(b.lastVisitAt!);
    });
}

/// A point of RTDB `location_history/{uid}/{day}`.
class RoutePoint {
  const RoutePoint({required this.lat, required this.lng, required this.t, this.accuracy, this.mocked = false});

  final double lat;
  final double lng;
  final DateTime t;
  final double? accuracy;
  final bool mocked;
}

/// Faster than this between two points means they can't be the same phone.
const _maxTrackKmh = 200.0;

/// Points that belong to one continuous track: with two phones signed in to
/// one account (e.g. a manager opening it in another city), both phones'
/// positions end up in the same day and the route zigzags between them.
/// Each point joins the track whose last point it could have driven from
/// (≤ [_maxTrackKmh], or within 5 km: points queued while offline arrive
/// together with one server time); the track with the most points is
/// kept, plus tracks of 5+ points that don't overlap it in time (e.g. a
/// new phone later in the day). Same logic as `mainTrack` in
/// functions/index.js.
///
/// Rough fixes (accuracy over 100 m) are left out first, as everywhere else
/// on the route.
List<RoutePoint> mainTrack(List<RoutePoint> points) {
  final sorted = points.where((p) => (p.accuracy ?? 0) <= _maxAccuracy).toList()..sort((a, b) => a.t.compareTo(b.t));
  final tracks = <List<RoutePoint>>[];
  for (final p in sorted) {
    List<RoutePoint>? best;
    for (final track in tracks) {
      final last = track.last;
      final meters = distanceBetween(last.lat, last.lng, p.lat, p.lng);
      final hours = p.t.difference(last.t).inMilliseconds / 3600000;
      final ok = meters <= 5000 || meters / 1000 <= _maxTrackKmh * hours;
      if (ok && (best == null || last.t.isAfter(best.last.t))) best = track;
    }
    if (best == null) {
      tracks.add([p]);
    } else {
      best.add(p);
    }
  }
  if (tracks.length < 2) return sorted;
  tracks.sort((a, b) => b.length.compareTo(a.length));
  final main = tracks.first;
  final kept = [
    ...main,
    for (final t in tracks.skip(1))
      if (t.length >= 5 && (t.last.t.isBefore(main.first.t) || t.first.t.isAfter(main.last.t))) ...t,
  ]..sort((a, b) => a.t.compareTo(b.t));
  return kept;
}

class RouteSummary {
  const RouteSummary({required this.path, required this.distanceMeters, required this.mockedPoints});

  /// Usable points in time order (rough fixes left out).
  final List<RoutePoint> path;
  final double distanceMeters;
  final int mockedPoints;

  DateTime? get first => path.isEmpty ? null : path.first.t;
  DateTime? get last => path.isEmpty ? null : path.last.t;
}

/// Fixes rougher than this are left out of the route.
const _maxAccuracy = 100.0;

/// Moves shorter than this (or than the fixes' accuracy) count as standing
/// still, so GPS jitter at a client doesn't add up to kilometres.
const _minMove = 25.0;

RouteSummary summarizeRoute(List<RoutePoint> points) {
  final path = points.where((p) => (p.accuracy ?? 0) <= _maxAccuracy).toList()..sort((a, b) => a.t.compareTo(b.t));
  var distance = 0.0;
  RoutePoint? from;
  for (final p in path) {
    if (from == null) {
      from = p;
      continue;
    }
    final d = distanceBetween(from.lat, from.lng, p.lat, p.lng);
    if (d > math.max(_minMove, math.max(from.accuracy ?? 0, p.accuracy ?? 0))) {
      distance += d;
      from = p;
    }
  }
  return RouteSummary(path: path, distanceMeters: distance, mockedPoints: path.where((p) => p.mocked).length);
}

/// No location for longer than this (phone offline, GPS off) is a gap in
/// tracking, not travel.
const routeGap = Duration(minutes: 15);

/// [path] (in time order) cut into runs of continuous tracking.
List<List<RoutePoint>> splitAtGaps(List<RoutePoint> path, {Duration gap = routeGap}) {
  final runs = <List<RoutePoint>>[];
  for (final p in path) {
    if (runs.isEmpty || p.t.difference(runs.last.last.t) > gap) {
      runs.add([p]);
    } else {
      runs.last.add(p);
    }
  }
  return runs;
}

/// Great-circle distance in meters.
double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// A stretch of route between two fixes, snapped to roads by the `snapRoute`
/// Cloud Function (RTDB `route_snapped/{uid}/{day}/legs`).
class SnappedLeg {
  const SnappedLeg({required this.from, required this.to, required this.meters, this.points});

  final DateTime from;
  final DateTime to;
  final double meters;

  /// Road shape; null = no believable road route, drawn along the fixes.
  final List<(double, double)>? points;
}

/// One person's day from `route_snapped`: [handled] = history points the
/// function has seen (when it equals the history count, nothing is pending).
class SnappedRoute {
  const SnappedRoute({this.handled = 0, this.legs = const []});

  final int handled;
  final List<SnappedLeg> legs;
}

/// Decodes a Google encoded polyline into (lat, lng) pairs.
List<(double, double)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0, lat = 0, lng = 0;
  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < encoded.length);
    // Not `~`: on the web it gives an unsigned 32-bit number.
    return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}

/// The line drawn for each run and the distance travelled: road shapes where
/// [legs] cover the run, straight lines between fixes elsewhere (e.g. fixes
/// not snapped yet). Fixes inside a leg (standing at a client) are skipped.
({List<List<(double, double)>> lines, double meters}) routeLines(List<List<RoutePoint>> runs, List<SnappedLeg> legs) {
  final sorted = [...legs]..sort((a, b) => a.from.compareTo(b.from));
  final lines = <List<(double, double)>>[];
  var meters = 0.0;
  void straight(List<RoutePoint> piece, List<(double, double)> line) {
    if (piece.length < 2) return;
    // The first fix is already the end of the line when a leg came before.
    line.addAll([for (final p in piece.skip(line.isEmpty ? 0 : 1)) (p.lat, p.lng)]);
    meters += summarizeRoute(piece).distanceMeters;
  }

  for (final run in runs) {
    final line = <(double, double)>[];
    var cursor = run.first.t;
    for (final leg in sorted) {
      if (leg.from.isBefore(cursor) || leg.to.isAfter(run.last.t)) continue;
      straight([for (final p in run) if (!p.t.isBefore(cursor) && !p.t.isAfter(leg.from)) p], line);
      final from = run.firstWhere((p) => p.t == leg.from, orElse: () => run.first);
      final to = run.firstWhere((p) => p.t == leg.to, orElse: () => run.last);
      // No believable road route: along the fixes (since 2026-10-26 the
      // server's meters are the distance along them too).
      final along = [for (final p in run) if (!p.t.isBefore(leg.from) && !p.t.isAfter(leg.to)) (p.lat, p.lng)];
      line.addAll(leg.points ?? (along.length >= 2 ? along : [(from.lat, from.lng), (to.lat, to.lng)]));
      meters += leg.meters;
      cursor = leg.to;
    }
    straight([for (final p in run) if (!p.t.isBefore(cursor)) p], line);
    lines.add(line);
  }
  // Across tracking gaps the way taken is unknown: counted straight, as before.
  for (var i = 1; i < runs.length; i++) {
    final (a, b) = (runs[i - 1].last, runs[i].first);
    meters += distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }
  return (lines: lines, meters: meters);
}
