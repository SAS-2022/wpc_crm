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

  bool get checkedIn => checkInAt != null;
  bool get closed => checkOutAt != null;
}

DayResult deriveDay(
  List<AttendanceEvent> events, {
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

  int? worked, counted, overtime;
  if (closed) {
    final inAt = checkInAt!, outAt = checkOutAt!;
    worked = _minutes(outAt.difference(inAt));
    final extra = outAt.difference(later(end, inAt));
    overtime = overtimeAllowed ? _minutes(extra) : 0;
    counted = overtimeAllowed ? worked : _minutes((outAt.isBefore(end) ? outAt : end).difference(inAt));
  }
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
  );
}

int _minutes(Duration d) => d.isNegative ? 0 : (d.inSeconds / 60).round();

/// "8 h 05" style.
String formatMinutes(int minutes) => '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
