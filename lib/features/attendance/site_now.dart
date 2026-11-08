import '../clients/client.dart' show metersBetween;
import 'attendance_rules.dart';
import 'work_sites.dart';

/// Employee Map site filter (user 2026-11-07: picking a site didn't narrow
/// the list — 28 of 38 people are assigned to the Service Center, 17 to 2+
/// sites). Where a person is now:
/// - a fresh position (≤ [freshFor] old) inside a site (radius + accuracy
///   up to 100 m + 50 m) → that site; a fresh position elsewhere → none;
/// - else checked in and inside → the site of the latest arrival event;
/// - else null (not at a site / unknown).
String? siteNow({
  required List<WorkSite> sites,
  double? lat,
  double? lng,
  double? accuracy,
  DateTime? at,
  required DateTime now,
  bool inside = false,
  List<AttendanceEvent> events = const [],
  Duration freshFor = const Duration(minutes: 30),
}) {
  if (lat != null && lng != null && at != null && now.difference(at) <= freshFor) {
    final margin = (accuracy ?? 0).clamp(0, 100) + 50;
    String? best;
    var bestD = double.infinity;
    for (final s in sites) {
      final d = metersBetween(lat, lng, s.lat, s.lng);
      if (d <= s.radius + margin && d < bestD) {
        best = s.id;
        bestD = d;
      }
    }
    return best;
  }
  if (!inside) return null;
  final arrivals = [
    for (final e in events)
      if (e.siteId != null &&
          (e.type == AttendanceEventType.in_ ||
              e.type == AttendanceEventType.checkIn ||
              e.type == AttendanceEventType.hrIn ||
              e.type == AttendanceEventType.seen))
        e,
  ]..sort((a, b) => a.at.compareTo(b.at));
  return arrivals.isEmpty ? null : arrivals.last.siteId;
}

/// Whether the person shows under site [siteId]: at it now, or not at any
/// site now and assigned to it.
bool showsUnderSite(String siteId, {required String? now, required List<String> assigned}) =>
    now == siteId || (now == null && assigned.contains(siteId));
