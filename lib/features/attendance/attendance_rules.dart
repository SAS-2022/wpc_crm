// Attendance rules, same as functions/attendance.js (keep both in sync; the
// server's result is what counts, this copy shows it on the phone at once,
// also offline). See that file for the rules (user decisions 2026-10-19).

/// What a phone records: arrived / left (geofence) or the buttons; hrIn /
/// hrOut come only from HR's correction of the day ([correctedEvents]).
enum AttendanceEventType { in_, out, checkIn, checkOut, hrIn, hrOut }

AttendanceEventType? eventTypeFromKey(Object? key) => switch (key) {
      'in' => AttendanceEventType.in_,
      'out' => AttendanceEventType.out,
      'checkIn' => AttendanceEventType.checkIn,
      'checkOut' => AttendanceEventType.checkOut,
      'hrIn' => AttendanceEventType.hrIn,
      'hrOut' => AttendanceEventType.hrOut,
      _ => null,
    };

String eventTypeKey(AttendanceEventType t) => switch (t) {
      AttendanceEventType.in_ => 'in',
      AttendanceEventType.out => 'out',
      AttendanceEventType.checkIn => 'checkIn',
      AttendanceEventType.checkOut => 'checkOut',
      AttendanceEventType.hrIn => 'hrIn',
      AttendanceEventType.hrOut => 'hrOut',
    };

class AttendanceEvent {
  const AttendanceEvent(this.type, this.at, {this.siteId});

  final AttendanceEventType type;
  final DateTime at;
  final String? siteId;
}

/// left | manual | leftSite | leftEarly | endOfDay | auto | hr
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
    this.awayMin,
  });

  final DateTime? checkInAt;

  /// 'auto' (arrived), 'manual' (button) or 'hr' (corrected by HR).
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

  /// Minutes between a check-out and checking in again the same day (not
  /// counted; 2026-10-22). Null on days worked out before it existed.
  final int? awayMin;

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
        awayMin: awayMin ?? other.awayMin,
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
  int overtimeMaxMin = defaultOvertimeMaxMin,
  DateTime? lastSeenAt,
  Duration? awayGrace,
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

  // Time between a check-out and coming back, before / after the end.
  var awayBefore = Duration.zero, awayAfter = Duration.zero;
  void reopen(DateTime at) {
    final out = checkOutAt!;
    final before = (at.isBefore(end) ? at : end).difference(out);
    final after = at.difference(out.isAfter(end) ? out : end);
    if (!before.isNegative) awayBefore += before;
    if (!after.isNegative) awayAfter += after;
    closed = false;
    checkOutAt = null;
    outType = null;
  }

  final grace = awayGrace ?? Duration(minutes: awayGraceMin);
  final cap = Duration(minutes: overtimeMaxMin);
  // Last time the person was seen at the site (arrival / check-in events, GPS).
  var seenAt = lastSeenAt;
  // Not allowed to leave, left before the end and away longer than the grace time at [t].
  bool awayTooLong(DateTime t) =>
      !leavesSite && checkInAt != null && !closed && !inside &&
      lastExitAt != null && lastExitAt.isBefore(end) && !t.isBefore(lastExitAt.add(grace));

  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  for (final e in sorted) {
    if (awayTooLong(e.at)) close(lastExitAt!, 'leftSite');
    switch (e.type) {
      case AttendanceEventType.in_ || AttendanceEventType.checkIn || AttendanceEventType.hrIn:
        if (seenAt == null || e.at.isAfter(seenAt)) seenAt = e.at;
        if (checkInAt == null) {
          checkInAt = e.at;
          source = switch (e.type) {
            AttendanceEventType.checkIn => 'manual',
            AttendanceEventType.hrIn => 'hr',
            _ => 'auto',
          };
          siteId = e.siteId;
        } else if (closed) {
          // A manual check-in reopens the day; so does arriving before the
          // end after being checked out for leaving the site.
          final back = e.type != AttendanceEventType.in_ || (outType == 'leftSite' && e.at.isBefore(end));
          if (!back) {
            inside = true;
            continue;
          }
          reopen(e.at);
        }
        inside = true;
        lastExitAt = null;
      case AttendanceEventType.out:
        inside = false;
        if (checkInAt == null || closed) continue;
        lastExitAt = e.at;
        if (!e.at.isBefore(end)) close(e.at, 'left');
      case AttendanceEventType.checkOut || AttendanceEventType.hrOut:
        if (checkInAt != null && !closed) close(e.at, e.type == AttendanceEventType.hrOut ? 'hr' : 'manual');
    }
  }
  DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  if (awayTooLong(now)) close(lastExitAt!, 'leftSite');
  if (checkInAt != null && !closed && !now.isBefore(end) && !inside) {
    if (leavesSite) {
      close(later(end, checkInAt), 'endOfDay');
    } else {
      close(lastExitAt ?? end, 'leftEarly');
    }
  }
  if (checkInAt != null && !closed && !now.isBefore(closeAll)) {
    // No exit seen: the end of the work day, or with overtime the last time
    // they were seen at the site (up to the cap).
    final from = later(end, checkInAt);
    final seen = seenAt;
    close(
      overtimeAllowed && seen != null
          ? (seen.isAfter(from.add(cap)) ? from.add(cap) : later(seen, from))
          : from,
      'auto',
    );
  }

  int? worked, counted, overtime, afterHours;
  if (closed) {
    final inAt = checkInAt!, outAt = checkOutAt!;
    worked = _minutes(outAt.difference(inAt) - awayBefore - awayAfter);
    final extra = outAt.difference(later(end, inAt)) - awayAfter;
    final extraMin = _minutes(extra);
    overtime = overtimeAllowed ? (extraMin < overtimeMaxMin ? extraMin : overtimeMaxMin) : 0;
    afterHours = extraMin - overtime;
    counted = overtimeAllowed
        ? (worked - afterHours < 0 ? 0 : worked - afterHours)
        : _minutes((outAt.isBefore(end) ? outAt : end).difference(inAt) - awayBefore);
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
    awayMin: _minutes(awayBefore + awayAfter),
  );
}

/// HR's correction of a day (2026-10-22): stored on the attendance day as
/// `correction` {checkInAt, checkOutAt?, siteId?, note, byId, at}.
class AttendanceCorrection {
  const AttendanceCorrection({required this.checkInAt, this.checkOutAt, this.siteId, this.note = '', this.byId = ''});

  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String? siteId;
  final String note;
  final String byId;
}

/// The day's events with HR's correction applied: checked in at its time;
/// out at its check-out when given, else the phone's events after the
/// check-in go on. Same as `correctedEvents` in functions/attendance.js.
List<AttendanceEvent> correctedEvents(List<AttendanceEvent> events, AttendanceCorrection? c) {
  final phone = [
    for (final e in events)
      if (e.type != AttendanceEventType.hrIn && e.type != AttendanceEventType.hrOut) e,
  ];
  if (c == null) return phone;
  final first = AttendanceEvent(AttendanceEventType.hrIn, c.checkInAt, siteId: c.siteId);
  if (c.checkOutAt != null) return [first, AttendanceEvent(AttendanceEventType.hrOut, c.checkOutAt!)];
  return [first, for (final e in phone) if (e.at.isAfter(c.checkInAt)) e];
}

/// Away from the site longer than this (people not allowed to leave it) →
/// checked out at the time they left (2026-10-22). Editable in App settings.
var awayGraceMin = 30;

/// Most overtime counted a day unless the user form sets more (user
/// decision 2026-10-24; `OVERTIME_MAX_MIN` in attendance.js).
const defaultOvertimeMaxMin = 180;

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
