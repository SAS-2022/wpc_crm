// Attendance rules, same as functions/attendance.js (keep both in sync; the
// server's result is what counts, this copy shows it on the phone at once,
// also offline). See that file for the rules (user decisions 2026-10-19).

/// What a phone records: arrived / left (geofence) or the buttons.
enum AttendanceEventType { in_, out, checkIn, checkOut }

AttendanceEventType? eventTypeFromKey(Object? key) => switch (key) {
      'in' => AttendanceEventType.in_,
      'out' => AttendanceEventType.out,
      'checkIn' => AttendanceEventType.checkIn,
      'checkOut' => AttendanceEventType.checkOut,
      _ => null,
    };

String eventTypeKey(AttendanceEventType t) => switch (t) {
      AttendanceEventType.in_ => 'in',
      AttendanceEventType.out => 'out',
      AttendanceEventType.checkIn => 'checkIn',
      AttendanceEventType.checkOut => 'checkOut',
    };

class AttendanceEvent {
  const AttendanceEvent(this.type, this.at, {this.siteId});

  final AttendanceEventType type;
  final DateTime at;
  final String? siteId;
}

/// left | manual | leftEarly | endOfDay | auto
class DayResult {
  const DayResult({
    this.checkInAt,
    this.checkInSource,
    this.siteId,
    this.inside = false,
    this.lastExitAt,
    this.checkOutAt,
    this.checkOutType,
    this.workedMin,
    this.countedMin,
    this.overtimeMin,
    this.lateMin,
    this.afterHoursMin,
  });

  final DateTime? checkInAt;

  /// 'auto' (arrived) or 'manual' (button).
  final String? checkInSource;
  final String? siteId;
  final bool inside;
  final DateTime? lastExitAt;
  final DateTime? checkOutAt;
  final String? checkOutType;
  final int? workedMin;
  final int? countedMin;
  final int? overtimeMin;

  /// Minutes after the start of their work day they checked in (0 = on
  /// time or within [lateGraceMin]; null = not checked in, or not a work day).
  final int? lateMin;

  /// Without overtime: minutes they stayed after the end of the work day
  /// (recorded, not counted; 2026-10-20). With overtime it's [overtimeMin].
  final int? afterHoursMin;

  bool get checkedIn => checkInAt != null;
  bool get closed => checkOutAt != null;

  /// This result with [lateMin] / [afterHoursMin] taken from [other] where
  /// it has none (days the server worked out before those existed).
  DayResult fillFrom(DayResult other) => DayResult(
        checkInAt: checkInAt,
        checkInSource: checkInSource,
        siteId: siteId,
        inside: inside,
        lastExitAt: lastExitAt,
        checkOutAt: checkOutAt,
        checkOutType: checkOutType,
        workedMin: workedMin,
        countedMin: countedMin,
        overtimeMin: overtimeMin,
        lateMin: lateMin ?? other.lateMin,
        afterHoursMin: afterHoursMin ?? other.afterHoursMin,
      );
}

DayResult deriveDay(
  List<AttendanceEvent> events, {
  DateTime? start,
  required DateTime end,
  required DateTime closeAll,
  required DateTime now,
  required bool leavesSite,
  required bool overtimeAllowed,
}) {
  DateTime? checkInAt, lastExitAt, checkOutAt;
  String? source, siteId, outType;
  var inside = false;
  var closed = false;
  void close(DateTime at, String type) {
    checkOutAt = at;
    outType = type;
    closed = true;
  }

  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  for (final e in sorted) {
    switch (e.type) {
      case AttendanceEventType.in_ || AttendanceEventType.checkIn:
        if (checkInAt == null) {
          checkInAt = e.at;
          source = e.type == AttendanceEventType.checkIn ? 'manual' : 'auto';
          siteId = e.siteId;
        } else if (closed) {
          if (e.type != AttendanceEventType.checkIn) {
            inside = true;
            continue;
          }
          closed = false;
          checkOutAt = null;
          outType = null;
        }
        inside = true;
        lastExitAt = null;
      case AttendanceEventType.out:
        inside = false;
        if (checkInAt == null || closed) continue;
        lastExitAt = e.at;
        if (!e.at.isBefore(end)) close(e.at, 'left');
      case AttendanceEventType.checkOut:
        if (checkInAt != null && !closed) close(e.at, 'manual');
    }
  }
  DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  if (checkInAt != null && !closed && !now.isBefore(end) && !inside) {
    if (leavesSite) {
      close(later(end, checkInAt), 'endOfDay');
    } else {
      close(lastExitAt ?? end, 'leftEarly');
    }
  }
  if (checkInAt != null && !closed && !now.isBefore(closeAll)) close(later(end, checkInAt), 'auto');

  int? worked, counted, overtime, afterHours;
  if (closed) {
    final inAt = checkInAt!, outAt = checkOutAt!;
    worked = _minutes(outAt.difference(inAt));
    final extra = outAt.difference(later(end, inAt));
    overtime = overtimeAllowed ? _minutes(extra) : 0;
    afterHours = overtimeAllowed ? 0 : _minutes(extra);
    counted = overtimeAllowed ? worked : _minutes((outAt.isBefore(end) ? outAt : end).difference(inAt));
  }
  final late = checkInAt == null || start == null ? null : lateMinutes(checkInAt.difference(start));
  return DayResult(
    checkInAt: checkInAt,
    checkInSource: source,
    siteId: siteId,
    inside: inside,
    lastExitAt: lastExitAt,
    checkOutAt: checkOutAt,
    checkOutType: outType,
    workedMin: worked,
    countedMin: counted,
    overtimeMin: overtime,
    lateMin: late,
    afterHoursMin: afterHours,
  );
}

/// Check-ins up to this many whole minutes after the start aren't late
/// (user decision 2026-10-20: 8:15 is on time, 8:16 is late). Editable in
/// App settings (`AppSettings.apply`; the server reads the same value).
var lateGraceMin = 15;

/// Minutes late (whole minutes after the start, seconds dropped), 0 within
/// the grace period. Same as `lateMinutes` in functions/attendance.js.
int lateMinutes(Duration afterStart) {
  final m = afterStart.inMinutes;
  return m > lateGraceMin ? m : 0;
}

int _minutes(Duration d) => d.isNegative ? 0 : (d.inSeconds / 60).round();

/// "8 h 05" style.
String formatMinutes(int minutes) => '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';

/// Whether a geofence event from the OS matches a fresh GPS fix
/// ([distance] from the site centre, [accuracy] of the fix, both in metres).
/// Android can report arrivals from a rough network position far from the
/// site (2026-10-21), so arrivals clearly outside and departures clearly
/// inside are ignored. A rough fix (worse than 150 m) can't tell: the OS is
/// trusted.
bool geofenceEventConfirmed({required bool enter, required double distance, required double accuracy, required double radius}) {
  if (accuracy > 150) return true;
  final margin = accuracy.clamp(0, 100);
  return enter ? distance <= radius + margin + 50 : distance + margin >= radius;
}
