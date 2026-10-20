import 'dart:math' as math;

import '../plan/route_order.dart' as route;
import '../plan/route_order.dart' show DayEfficiency, Stop, dayEfficiency;

// Routing measured from the salespeople's own days (user request
// 2026-10-20). The `buildTimelines` Cloud Function splits each working day
// into client / driving / office / lunch / stopped / no-data time
// (functions/timeline.js); from those days each person gets an average visit
// length, driving speed and road-vs-straight-line factor, and the team
// benchmark is the median of the people's averages. A day's "needed" time =
// visits × benchmark visit length + shortest route at the benchmark speed;
// "took" = first client arrival to last client departure minus lunch and
// office time.

/// Kinds of time in a day timeline (same keys as timeline.js).
enum TimeKind { client, driving, office, lunch, stopped, noData }

/// Minutes per kind.
typedef TimeSplit = Map<TimeKind, int>;

TimeSplit _split(Object? m) => {
      for (final k in TimeKind.values) k: m is Map ? ((m[k.name] as num?)?.toInt() ?? 0) : 0,
    };

TimeSplit addSplits(Iterable<TimeSplit> all) => {
      for (final k in TimeKind.values) k: all.fold(0, (s, x) => s + (x[k] ?? 0)),
    };

class ClientStay {
  const ClientStay({required this.clientId, required this.from, required this.to});

  final String clientId;
  final DateTime from;
  final DateTime to;

  Duration get length => to.difference(from);
}

class TimelineStop {
  const TimelineStop({required this.from, required this.to, required this.kind, this.lat, this.lng});

  final DateTime from;
  final DateTime to;

  /// [TimeKind.stopped], [TimeKind.lunch] or [TimeKind.office].
  final TimeKind kind;
  final double? lat;
  final double? lng;

  Duration get length => to.difference(from);
}

/// One person's day as built by the server (`day_timelines/{uid}_{day}`).
class DayTimeline {
  const DayTimeline({
    required this.uid,
    required this.day,
    required this.minutes,
    required this.drivingKm,
    required this.clientStays,
    required this.stops,
    this.firstClientAt,
    this.lastClientAt,
    this.between,
    this.betweenDrivingKm = 0,
    this.isFinal = false,
  });

  final String uid;

  /// 'yyyy-MM-dd'.
  final String day;

  /// The whole work day.
  final TimeSplit minutes;
  final double drivingKm;
  final List<ClientStay> clientStays;
  final List<TimelineStop> stops;

  /// Arrival at the first client and departure from the last one.
  final DateTime? firstClientAt;
  final DateTime? lastClientAt;

  /// The minutes between [firstClientAt] and [lastClientAt].
  final TimeSplit? between;
  final double betweenDrivingKm;

  /// False while the day is still going on.
  final bool isFinal;

  static DateTime? _time(Object? ms) => ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;

  factory DayTimeline.fromMap(Map<String, dynamic> d) {
    final between = d['between'];
    return DayTimeline(
      uid: d['uid'] as String? ?? '',
      day: d['day'] as String? ?? '',
      minutes: _split(d['minutes']),
      drivingKm: (d['drivingKm'] as num?)?.toDouble() ?? 0,
      clientStays: [
        for (final s in d['clientStays'] as List? ?? const [])
          if (s is Map && _time(s['from']) != null && _time(s['to']) != null)
            ClientStay(clientId: s['clientId'] as String? ?? '', from: _time(s['from'])!, to: _time(s['to'])!),
      ],
      stops: [
        for (final s in d['stops'] as List? ?? const [])
          if (s is Map && _time(s['from']) != null && _time(s['to']) != null)
            TimelineStop(
              from: _time(s['from'])!,
              to: _time(s['to'])!,
              kind: TimeKind.values.asNameMap()[s['kind']] ?? TimeKind.stopped,
              lat: (s['lat'] as num?)?.toDouble(),
              lng: (s['lng'] as num?)?.toDouble(),
            ),
      ],
      firstClientAt: _time(d['firstClientAt']),
      lastClientAt: _time(d['lastClientAt']),
      between: between is Map ? _split(between) : null,
      betweenDrivingKm: between is Map ? ((between['drivingKm'] as num?)?.toDouble() ?? 0) : 0,
      isFinal: d['final'] == true,
    );
  }
}

/// A visit counted for the benchmark at most this long (an outlier like a
/// whole afternoon at one client shouldn't move the average much).
const _maxVisitMinutes = 240;

/// One person's measured habits over the days given.
class PersonPace {
  const PersonPace({required this.uid, required this.days, this.visitMinutes, this.speedKmh, this.roadFactor});

  final String uid;

  /// Days with a timeline and at least one client stay.
  final int days;

  /// Average time at a client.
  final double? visitMinutes;

  /// Average driving speed between the first and last client.
  final double? speedKmh;

  /// Road km driven between clients ÷ straight-line km between them.
  final double? roadFactor;
}

/// [straightKmByDay]: 'yyyy-MM-dd' → straight-line km between that day's
/// visits in the order made (from the check-ins).
PersonPace personPace(String uid, List<DayTimeline> days, Map<String, double> straightKmByDay) {
  var stays = 0, stayMin = 0.0, km = 0.0, driveMin = 0.0, roadKm = 0.0, straightKm = 0.0, counted = 0;
  for (final d in days) {
    if (d.clientStays.isEmpty) continue;
    counted++;
    for (final s in d.clientStays) {
      stays++;
      stayMin += math.min(s.length.inSeconds / 60, _maxVisitMinutes);
    }
    final b = d.between;
    if (b != null && d.clientStays.length >= 2) {
      km += d.betweenDrivingKm;
      driveMin += b[TimeKind.driving] ?? 0;
      final straight = straightKmByDay[d.day];
      if (straight != null && straight > 0.2) {
        roadKm += d.betweenDrivingKm;
        straightKm += straight;
      }
    }
  }
  return PersonPace(
    uid: uid,
    days: counted,
    visitMinutes: stays == 0 ? null : stayMin / stays,
    // Less than half an hour of driving says little about speed.
    speedKmh: driveMin < 30 ? null : km / (driveMin / 60),
    roadFactor: straightKm < 1 ? null : (roadKm / straightKm).clamp(1.0, 3.0),
  );
}

double? median(Iterable<double> values) {
  final v = values.toList()..sort();
  if (v.isEmpty) return null;
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

/// The team benchmark: the median of the people's averages. Values nobody
/// has data for fall back to the earlier fixed guesses.
class TeamPace {
  const TeamPace({
    required this.visitMinutes,
    required this.speedKmh,
    required this.roadFactor,
    required this.people,
    this.measured = const {},
  });

  /// The fixed guesses used before (30 min a visit, 40 km/h, roads 1.4×).
  static const defaults = TeamPace(
    visitMinutes: 30,
    speedKmh: route.travelKmh,
    roadFactor: route.roadFactor,
    people: 0,
  );

  final double visitMinutes;
  final double speedKmh;
  final double roadFactor;

  /// People whose days went into it.
  final int people;

  /// Which of the three come from measured data ('visit', 'speed', 'road').
  final Set<String> measured;

  /// Driving time for [straightKm] of straight line.
  Duration drive(double straightKm) => Duration(seconds: (straightKm * roadFactor / speedKmh * 3600).round());

  Duration get visit => Duration(seconds: (visitMinutes * 60).round());

  /// E.g. 10 visits with 30 km of straight line between them.
  Duration estimate(int visits, double straightKm) => visit * visits + drive(straightKm);
}

/// People with fewer days than this don't count towards the benchmark.
const minPaceDays = 2;

TeamPace teamPace(List<PersonPace> people) {
  final enough = people.where((p) => p.days >= minPaceDays).toList();
  final visit = median(enough.map((p) => p.visitMinutes).whereType<double>());
  final speed = median(enough.map((p) => p.speedKmh).whereType<double>());
  final road = median(enough.map((p) => p.roadFactor).whereType<double>());
  return TeamPace(
    visitMinutes: visit ?? TeamPace.defaults.visitMinutes,
    speedKmh: speed ?? TeamPace.defaults.speedKmh,
    roadFactor: road ?? TeamPace.defaults.roadFactor,
    people: enough.length,
    measured: {if (visit != null) 'visit', if (speed != null) 'speed', if (road != null) 'road'},
  );
}

/// A day's efficiency against the team benchmark. With a timeline, "took"
/// is the first client arrival to the last client departure minus lunch and
/// office time; without one (no GPS), first to last check-in plus one visit.
DayEfficiency? paceEfficiency(
  List<({DateTime at, Stop place})> visits, {
  required TeamPace pace,
  DayTimeline? timeline,
}) {
  final base = dayEfficiency(visits);
  if (base == null) return null;
  final n = visits.length;
  final needed = pace.estimate(n, base.shortestMeters / 1000);
  final b = timeline?.between;
  final first = timeline?.firstClientAt, last = timeline?.lastClientAt;
  final measured = b != null && first != null && last != null && (timeline!.clientStays.length >= 2);
  final took = measured
      ? last.difference(first) - Duration(minutes: (b[TimeKind.lunch] ?? 0) + (b[TimeKind.office] ?? 0))
      : base.took + pace.visit;
  return DayEfficiency(
    took: took.isNegative ? Duration.zero : took,
    needed: needed,
    takenMeters: base.takenMeters,
    shortestMeters: base.shortestMeters,
    measured: measured,
  );
}
