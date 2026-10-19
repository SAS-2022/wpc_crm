import 'dart:math' as math;

// Still / walking / driving and "idle since" for the live map (user request
// 2026-10-19). Worked out on the phone from the fixes it already gets and
// sent with the usual live location write (`stillSince`, `motion`): no extra
// writes, reads or GPS use.

enum Motion { still, walking, driving }

/// Moving less than this from where the person stopped counts as staying.
const stillRadiusMeters = 60.0;

/// Fixes rougher than this don't move the "stopped here" point.
const _roughFixMeters = 100.0;

/// m/s: about 2.5 km/h and 11 km/h.
const _walkingSpeed = 0.7;
const _drivingSpeed = 3.0;

class MotionTracker {
  double? _anchorLat, _anchorLng;
  DateTime? _anchorAt;
  double? _lastLat, _lastLng;
  DateTime? _lastAt;
  final _speeds = <double>[];

  /// Feeds one fix; returns since when the person has stayed within
  /// [stillRadiusMeters] and how they move (average of the last 3 speeds).
  ({DateTime stillSince, Motion motion}) update({
    required double lat,
    required double lng,
    required double accuracy,
    required double speed,
    required DateTime at,
  }) {
    final rough = accuracy > _roughFixMeters;
    if (_anchorAt == null) {
      _anchorLat = lat;
      _anchorLng = lng;
      _anchorAt = at;
    } else if (!rough && metersBetween(_anchorLat!, _anchorLng!, lat, lng) > stillRadiusMeters + math.min(accuracy, 40)) {
      _anchorLat = lat;
      _anchorLng = lng;
      _anchorAt = at;
    }

    // GPS speed when the phone gives one, else distance / time — counted
    // only when the step is bigger than the fix's own error (jitter).
    double? v = speed > 0 ? speed : null;
    if (v == null && _lastAt != null && !rough) {
      final seconds = at.difference(_lastAt!).inMilliseconds / 1000;
      final step = metersBetween(_lastLat!, _lastLng!, lat, lng);
      if (seconds > 0) v = step > accuracy ? step / seconds : 0;
    }
    _lastLat = lat;
    _lastLng = lng;
    _lastAt = at;
    if (v != null) {
      _speeds.add(v);
      if (_speeds.length > 3) _speeds.removeAt(0);
    }
    final avg = _speeds.isEmpty ? 0.0 : _speeds.reduce((a, b) => a + b) / _speeds.length;
    final motion = avg >= _drivingSpeed
        ? Motion.driving
        : avg >= _walkingSpeed
            ? Motion.walking
            : Motion.still;
    return (stillSince: _anchorAt!, motion: motion);
  }

  void reset() {
    _anchorLat = _anchorLng = _lastLat = _lastLng = null;
    _anchorAt = _lastAt = null;
    _speeds.clear();
  }
}

double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// How long the person has been in one place, as the live map shows it:
/// from `stillSince` to the fix (both phone clock), plus the time since the
/// write reached the server. Null when unknown (older app) or not still.
Duration? idleFor({
  required Motion? motion,
  required DateTime? stillSince,
  required DateTime? fixAt,
  required DateTime? updatedAt,
  required DateTime now,
}) {
  if (motion != Motion.still || stillSince == null || fixAt == null || updatedAt == null) return null;
  final atFix = fixAt.difference(stillSince);
  final sinceWrite = now.difference(updatedAt);
  final total = atFix + (sinceWrite.isNegative ? Duration.zero : sinceWrite);
  return total.isNegative ? Duration.zero : total;
}

/// Idle shown from this long on (user: "after for example 5 min").
const idleShownAfter = Duration(minutes: 5);
