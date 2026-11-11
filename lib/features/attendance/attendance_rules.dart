// Attendance rules, same as functions/attendance.js (keep both in sync; the
// server's result is what counts, this copy shows it on the phone at once,
// also offline). See that file for the rules (user decisions 2026-10-19).

/// What a phone records: arrived / left (geofence), the buttons, or still at
/// the site (`seen`, answer to a site check after the end of the work day,
/// 2026-10-25), "Start overtime" / "Not today" (otStart / otDecline,
/// 2026-10-25); hrIn / hrOut come only from HR's correction of the day
/// ([correctedEvents]).
enum AttendanceEventType { in_, out, checkIn, checkOut, seen, otStart, otDecline, hrIn, hrOut }

AttendanceEventType? eventTypeFromKey(Object? key) => switch (key) {
      'in' => AttendanceEventType.in_,
      'out' => AttendanceEventType.out,
      'checkIn' => AttendanceEventType.checkIn,
      'checkOut' => AttendanceEventType.checkOut,
      'seen' => AttendanceEventType.seen,
      'otStart' => AttendanceEventType.otStart,
      'otDecline' => AttendanceEventType.otDecline,
      'hrIn' => AttendanceEventType.hrIn,
      'hrOut' => AttendanceEventType.hrOut,
      _ => null,
    };

String eventTypeKey(AttendanceEventType t) => switch (t) {
      AttendanceEventType.in_ => 'in',
      AttendanceEventType.out => 'out',
      AttendanceEventType.checkIn => 'checkIn',
      AttendanceEventType.checkOut => 'checkOut',
      AttendanceEventType.seen => 'seen',
      AttendanceEventType.otStart => 'otStart',
      AttendanceEventType.otDecline => 'otDecline',
      AttendanceEventType.hrIn => 'hrIn',
      AttendanceEventType.hrOut => 'hrOut',
    };

class AttendanceEvent {
  const AttendanceEvent(this.type, this.at, {this.siteId, this.check = false, this.source});

  final AttendanceEventType type;
  final DateTime at;
  final String? siteId;

  /// 'gps' = added by the server from the GPS fixes (an `out` then means
  /// outside every site), 'hr', or null (the phone).
  final String? source;

  /// Recorded by a site check (an `out` then means "found gone").
  final bool check;
}

/// Driver overtime on a day (server, `driveOvertime`, 2026-10-25): started
/// at the end of the work day when the driver was on the road 10 min later;
/// ends on arriving home or at a work site ([place] 'home' | 'site'), at the
/// cap ('cap') or unknown (null, phone silent).
class DriveOvertime {
  const DriveOvertime({required this.startAt, this.endAt, this.place});

  final DateTime startAt;
  final DateTime? endAt;
  final String? place;

  bool get running => endAt == null;
}

/// left | manual | leftSite | leftEarly | endOfDay | auto | hr | arrivedHome | arrivedSite | overtimeCap
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
    this.breakMin,
    this.breakOverMin,
    this.lastSeenAt,
    this.overtimeOn = false,
    this.overtimeConfirmedAt,
    this.overtimeDeclined = false,
    this.overtimeEndUnknown = false,
    this.checkInEventAt,
  });

  final DateTime? checkInAt;

  /// 'auto' (arrived), 'manual' (button) or 'hr' (corrected by HR).
  final String? checkInSource;

  /// The check-in event's own time when GPS showed them at the site earlier
  /// ([checkInAt] = that arrival, 2026-10-28); null otherwise.
  final DateTime? checkInEventAt;
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

  /// Minutes out of the site before the end of the work day while checked
  /// in (people who request breaks, 2026-11-05) and how much of it is over
  /// the daily allowance ([breakAllowanceMin]; taken off [countedMin]).
  /// Null for everyone else and days worked out before.
  final int? breakMin;
  final int? breakOverMin;

  /// Last time the person was known to be at the site (arrival, check-in,
  /// site check, GPS fix).
  final DateTime? lastSeenAt;

  /// Overtime counts today: allowed and started ("Start overtime" or a
  /// driver on the road after the end; 2026-10-25).
  final bool overtimeOn;

  /// When they pressed "Start overtime" (it still counts from the end).
  final DateTime? overtimeConfirmedAt;

  /// "Not today" to the overtime question.
  final bool overtimeDeclined;

  /// Overtime started, closed with no exit / arrival seen and not seen up
  /// to the overtime cap: when it ended is unknown (HR may correct the
  /// day; 2026-10-25).
  final bool overtimeEndUnknown;

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
        breakMin: breakMin ?? other.breakMin,
        breakOverMin: breakOverMin ?? other.breakOverMin,
        lastSeenAt: lastSeenAt ?? other.lastSeenAt,
        overtimeOn: overtimeOn,
        overtimeConfirmedAt: overtimeConfirmedAt,
        overtimeDeclined: overtimeDeclined,
        overtimeEndUnknown: overtimeEndUnknown,
        checkInEventAt: checkInEventAt ?? other.checkInEventAt,
      );
}

/// [overtimeDayOff]: an overtime day a manager allowed (2026-11-08,
/// `overtime_days`; null = none): true = a day off / holiday, the whole stay
/// (arrival → leaving) is overtime, no cap, time out and back not counted;
/// false = a work day, the time after the end counts without "Start
/// overtime". Same as `deriveDay` in functions/attendance.js.
DayResult deriveDay(
  List<AttendanceEvent> events, {
  DateTime? start,
  required DateTime end,
  bool? overtimeDayOff,
  required DateTime closeAll,
  required DateTime now,
  required bool leavesSite,
  required bool overtimeAllowed,
  int overtimeMaxMin = defaultOvertimeMaxMin,
  DateTime? lastSeenAt,
  Duration? awayGrace,
  DriveOvertime? drive,
  DateTime? arrivedAt,
  List<BreakSlot> breaks = const [],
  int? breakAllowanceMin,
}) {
  final otDay = overtimeDayOff != null;
  final otDayOff = overtimeDayOff == true;
  if (otDayOff) {
    // Day off: the work day "ends" at midnight, so everything is after it.
    start = null;
    end = DateTime(closeAll.year, closeAll.month, closeAll.day);
    overtimeMaxMin = 24 * 60;
  }
  DateTime? checkInAt, lastExitAt, checkOutAt, checkInEventAt;
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
  // Breaks (2026-11-05): an approved break covering the last exit gives its
  // minutes on top of the grace time before "away too long" checks out.
  final takeBreak = breakTaker(breaks);
  var allowance = Duration.zero;
  // Time out of the site before the end while checked in: the daily break;
  // beyond [breakAllowanceMin] it's taken off the counted time (2026-11-05).
  var breakTime = Duration.zero;
  DateTime? outSince;
  void backIn(DateTime t) {
    final since = outSince;
    if (since != null && !closed) {
      final d = (t.isBefore(end) ? t : end).difference(since);
      if (!d.isNegative) breakTime += d;
    }
    outSince = null;
  }
  // Leaving before the work day starts isn't leaving work (2026-11-07:
  // workers moved from one site to another at 07:59): away time counts from the start.
  DateTime fromStart(DateTime t) => start != null && t.isBefore(start) ? start : t;
  // The site the person is in ('*' = unknown): an exit from another site
  // while inside one isn't leaving (2026-11-07: the phone's first report for
  // a site 20 km away said "exit"). Same as `strayExit` in attendance.js.
  String? inSite;
  void enter(AttendanceEvent e) => inSite = e.siteId == null || e.siteId!.isEmpty ? '*' : e.siteId;
  bool strayExit(AttendanceEvent e) => isStrayExit(e, inside: inside, inSite: inSite);
  // Last time the person was seen at the site (arrival / check-in events, GPS).
  var seenAt = lastSeenAt;
  // Not allowed to leave, left before the end and away longer than the grace time at [t].
  bool awayTooLong(DateTime t) =>
      !leavesSite && checkInAt != null && !closed && !inside &&
      lastExitAt != null && lastExitAt.isBefore(end) && !t.isBefore(fromStart(lastExitAt).add(grace + allowance));

  DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  // Overtime started ("Start overtime") / declined.
  DateTime? confirmedAt;
  var declined = false;
  final sorted = [
    for (final e in events)
      // Driving overtime: only a check-out counts after it started.
      if (drive == null ||
          !e.at.isAfter(drive.startAt) ||
          e.type == AttendanceEventType.checkOut ||
          e.type == AttendanceEventType.hrOut)
        e,
  ]..sort((a, b) => a.at.compareTo(b.at));
  for (final e in sorted) {
    if (awayTooLong(e.at)) {
      close(lastExitAt!, 'leftSite');
      outSince = null;
    }
    switch (e.type) {
      case AttendanceEventType.in_ || AttendanceEventType.checkIn || AttendanceEventType.hrIn:
        backIn(e.at);
        if (seenAt == null || e.at.isAfter(seenAt)) seenAt = e.at;
        if (checkInAt == null) {
          checkInAt = e.at;
          // At the site before the check-in (GPS, server's `arrivedAt`): the day starts then.
          if (e.type != AttendanceEventType.hrIn && arrivedAt != null && arrivedAt.isBefore(e.at)) {
            checkInAt = arrivedAt;
            checkInEventAt = e.at;
          }
          source = switch (e.type) {
            AttendanceEventType.checkIn => 'manual',
            AttendanceEventType.hrIn => 'hr',
            _ => 'auto',
          };
          siteId = e.siteId;
        } else if (closed) {
          // A manual check-in reopens the day; so does arriving before the
          // end after being checked out for leaving the site.
          final back = e.type != AttendanceEventType.in_ ||
              (outType == 'leftSite' && e.at.isBefore(end)) ||
              (otDayOff && outType == 'left');
          if (!back) {
            inside = true;
            enter(e);
            continue;
          }
          reopen(e.at);
        }
        inside = true;
        enter(e);
        lastExitAt = null;
      case AttendanceEventType.otStart:
        if (checkInAt != null && !closed) confirmedAt ??= e.at;
      case AttendanceEventType.otDecline:
        if (checkInAt != null && !closed) declined = true;
      case AttendanceEventType.seen:
        backIn(e.at);
        if (seenAt == null || e.at.isAfter(seenAt)) seenAt = e.at;
        if (checkInAt != null && !closed) {
          inside = true;
          enter(e);
          lastExitAt = null;
        }
      case AttendanceEventType.out:
        if (strayExit(e)) continue;
        final wasInside = inside;
        inside = false;
        inSite = null;
        if (checkInAt == null || closed) continue;
        // Already away when the end came (allowed to leave): the day closed at
        // the end; a later exit (e.g. geofences registered again) doesn't move it.
        if (!wasInside && leavesSite && drive == null && !e.at.isBefore(end)) {
          close(later(end, checkInAt), 'endOfDay');
          continue;
        }
        // Found gone by a site check: left after they were last seen.
        final seen = seenAt;
        final at = e.check && seen != null ? _earlier(e.at, later(later(seen, end), checkInAt)) : e.at;
        lastExitAt = at;
        if (!e.at.isBefore(end)) {
          close(at, 'left');
        } else {
          final slot = takeBreak(at);
          allowance = slot != null && slot.status == BreakStatus.approved ? Duration(minutes: slot.minutes) : Duration.zero;
          if (wasInside) outSince = fromStart(at);
        }
      case AttendanceEventType.checkOut || AttendanceEventType.hrOut:
        if (checkInAt != null && !closed) close(e.at, e.type == AttendanceEventType.hrOut ? 'hr' : 'manual');
        outSince = null;
    }
  }
  // Still out and the day still open (not checked out below for it): counts up to now.
  if (outSince != null && !closed && now.isBefore(end) && !awayTooLong(now)) backIn(now);
  final overtimeOn = otDay || (overtimeAllowed && (drive != null || confirmedAt != null));
  if (drive != null && checkInAt != null && !closed) {
    // Driving: open until the server finds the arrival (or the cap).
    final endAt = drive.endAt;
    if (endAt != null) {
      final type = switch (drive.place) {
        'home' => 'arrivedHome',
        'site' => 'arrivedSite',
        'cap' => 'overtimeCap',
        _ => 'auto',
      };
      close(later(later(endAt, end), checkInAt), type);
    }
  } else {
    if (awayTooLong(now)) close(lastExitAt!, 'leftSite');
    if (checkInAt != null && !closed && !now.isBefore(end) && !inside) {
      if (leavesSite) {
        close(later(end, checkInAt), 'endOfDay');
      } else {
        close(lastExitAt ?? end, 'leftEarly');
      }
    }
    if (checkInAt != null && !closed && !now.isBefore(closeAll)) {
      // No exit seen: the end of the work day, or with overtime started the
      // last time they were seen at the site (up to the cap).
      final from = later(end, checkInAt);
      final seen = seenAt;
      close(
        overtimeOn && seen != null ? (seen.isAfter(from.add(cap)) ? from.add(cap) : later(seen, from)) : from,
        'auto',
      );
    }
  }

  int? worked, counted, overtime, afterHours;
  if (closed) {
    final inAt = checkInAt!, outAt = checkOutAt!;
    worked = _minutes(outAt.difference(inAt) - awayBefore - awayAfter);
    final extra = outAt.difference(later(end, inAt)) - awayAfter;
    final extraMin = _minutes(extra);
    overtime = overtimeOn ? (extraMin < overtimeMaxMin ? extraMin : overtimeMaxMin) : 0;
    if (overtime < minOvertimeMin) overtime = 0;
    afterHours = extraMin - overtime;
    counted = overtimeOn
        ? (worked - afterHours < 0 ? 0 : worked - afterHours)
        : _minutes((outAt.isBefore(end) ? outAt : end).difference(inAt) - awayBefore);
  }
  final breakTotal = breakAllowanceMin == null ? null : _minutes(breakTime);
  final breakOver = breakTotal == null ? null : (breakTotal - breakAllowanceMin! > 0 ? breakTotal - breakAllowanceMin : 0);
  if (counted != null && (breakOver ?? 0) > 0) counted = counted - breakOver! < 0 ? 0 : counted - breakOver;
  final late = checkInAt == null || start == null ? null : lateMinutes(checkInAt.difference(start));
  // Overtime started, no exit / arrival seen and not seen up to the cap: when it ended is unknown.
  final endUnknown = closed && outType == 'auto' && overtimeOn && checkOutAt!.isBefore(later(end, checkInAt!).add(cap));
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
    breakMin: breakTotal,
    breakOverMin: breakOver,
    lastSeenAt: seenAt,
    overtimeOn: overtimeOn,
    overtimeConfirmedAt: confirmedAt,
    overtimeDeclined: declined,
    overtimeEndUnknown: endUnknown,
    checkInEventAt: checkInEventAt,
  );
}

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

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

/// Break time a day before the rest is taken off the counted hours (user
/// decision 2026-11-05: 9 hours with 1 hour of break). Editable in App
/// settings; `BREAK_ALLOWANCE_MIN` in attendance.js.
var breakAllowanceMin = 60;

/// Overtime shorter than this many minutes counts as none: the time is
/// after-hours (recorded, not counted) instead (user decision 2026-11-10).
/// Editable in App settings; `MIN_OVERTIME_MIN` in attendance.js.
var minOvertimeMin = 29;

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

/// What a site check's GPS fix says (2026-10-25): [distance] from the site
/// centre and the fix [accuracy] in metres. Within the radius (plus the fix
/// accuracy, up to 100 m) = still there; clearly beyond it (50 m more) =
/// gone; a rough fix (worse than 150 m) or the edge in between can't tell.
enum SiteCheckResult { seen, gone, unknown }

SiteCheckResult siteCheckResult({required double distance, required double accuracy, required double radius}) {
  if (accuracy > 150) return SiteCheckResult.unknown;
  final margin = accuracy.clamp(0, 100);
  if (distance <= radius + margin) return SiteCheckResult.seen;
  if (distance - margin > radius + 50) return SiteCheckResult.gone;
  return SiteCheckResult.unknown;
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

/// One trip away from the site and back on a day (2026-11-04, user: the
/// Attendance page should show that someone left and came back).
typedef SiteTrip = ({DateTime leftAt, DateTime backAt});

/// An exit from another site while the person is inside [inSite] (a site
/// id; '*' = unknown): not leaving (2026-11-07). GPS exits (outside every
/// site) and site-check exits always count. `strayExit` in attendance.js.
bool isStrayExit(AttendanceEvent e, {required bool inside, required String? inSite}) =>
    inside && inSite != null && inSite != '*' && e.source != 'gps' && !e.check &&
    e.siteId != null && e.siteId!.isNotEmpty && e.siteId != inSite;

/// Trips shorter than this are taken as geofence jitter at the edge.
const minSiteTripMin = 3;

/// The day's trips out of the site and back, from the (corrected) [events]:
/// an exit after the person was in, followed by an arrival (geofence, button,
/// GPS, HR or a site check finding them there). A check-out ends the stay
/// (the time after it is no trip), and the exit they are still away on now
/// is left out (the page already says "Left the site at …"). Display only:
/// the counted hours come from [deriveDay].
List<SiteTrip> siteTrips(List<AttendanceEvent> events) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  final trips = <SiteTrip>[];
  var inside = false;
  String? inSite;
  DateTime? leftAt;
  for (final e in sorted) {
    switch (e.type) {
      case AttendanceEventType.in_ || AttendanceEventType.checkIn || AttendanceEventType.hrIn || AttendanceEventType.seen:
        if (!inside && leftAt != null && e.at.difference(leftAt).inMinutes >= minSiteTripMin) {
          trips.add((leftAt: leftAt, backAt: e.at));
        }
        inside = true;
        inSite = e.siteId == null || e.siteId!.isEmpty ? '*' : e.siteId;
        leftAt = null;
      case AttendanceEventType.out:
        if (isStrayExit(e, inside: inside, inSite: inSite)) continue;
        if (inside) leftAt = e.at;
        inside = false;
        inSite = null;
      case AttendanceEventType.checkOut || AttendanceEventType.hrOut:
        inside = false;
        leftAt = null;
      case AttendanceEventType.otStart || AttendanceEventType.otDecline:
        break;
    }
  }
  return trips;
}

/// Break requests (2026-11-05, `break_request.dart`): pending until the
/// supervisor / department head answers; a pending one is never carried to
/// the next day.
enum BreakStatus {
  pending,
  approved,
  rejected;

  static BreakStatus fromKey(Object? key) => values.asNameMap()[key] ?? pending;
}

/// A break request as copied onto the attendance day by the server
/// (`attendance.breaks` [{id, at, minutes, status, decidedBy}]; `at` = when
/// it was asked).
class BreakSlot {
  const BreakSlot({required this.id, required this.at, required this.minutes, this.status = BreakStatus.pending, this.decidedBy});

  final String id;
  final DateTime at;
  final int minutes;
  final BreakStatus status;
  final String? decidedBy;
}

/// A request made up to this long after the exit still covers it (the
/// phone often reports the exit a little late). `BREAK_SLACK_MS` in attendance.js.
const breakMatchSlack = Duration(minutes: 5);

/// Gives each exit (called in time order) the latest unused break asked
/// before it (or within [breakMatchSlack] after); null = none. An old,
/// unused request (e.g. refused in the morning) doesn't cover a later exit
/// that has a newer one. Same as `breakTaker` in functions/attendance.js.
BreakSlot? Function(DateTime exitAt) breakTaker(List<BreakSlot> breaks) {
  final newestFirst = [...breaks]..sort((a, b) => b.at.compareTo(a.at));
  final used = <String>{};
  return (exitAt) {
    for (final b in newestFirst) {
      if (used.contains(b.id) || b.at.isAfter(exitAt.add(breakMatchSlack))) continue;
      used.add(b.id);
      return b;
    }
    return null;
  };
}

/// Whether leaving the site was allowed (display, 2026-11-05).
enum ExitPermission { onBreak, waiting, refused, none }

/// One exit from the site before the end of the work day, with the break
/// that covers it.
class ExitCheck {
  const ExitCheck({required this.leftAt, this.backAt, this.slot});

  final DateTime leftAt;

  /// Null = still away (or checked out for it).
  final DateTime? backAt;
  final BreakSlot? slot;

  ExitPermission get permission => switch (slot?.status) {
        BreakStatus.approved => ExitPermission.onBreak,
        BreakStatus.pending => ExitPermission.waiting,
        BreakStatus.rejected => ExitPermission.refused,
        null => ExitPermission.none,
      };

  /// Left without an approved break.
  bool get withoutPermission => permission != ExitPermission.onBreak;

  /// Minutes away longer than the approved break (0 when not back yet).
  int get overMin {
    final s = slot, back = backAt;
    if (s == null || back == null || s.status != BreakStatus.approved) return 0;
    final over = back.difference(leftAt).inMinutes - s.minutes;
    return over > 0 ? over : 0;
  }
}

/// The day's exits between [start] and [end] (trips out and back, plus the exit they're
/// still away on or were checked out for), each with its break.
/// Exits before [start] (the work day hadn't begun) are left out (2026-11-07).
List<ExitCheck> checkExits(List<({DateTime leftAt, DateTime? backAt})> exits, List<BreakSlot> breaks, DateTime end,
    {DateTime? start}) {
  final sorted = [
    for (final e in exits)
      if (e.leftAt.isBefore(end) && (start == null || !e.leftAt.isBefore(start))) e
  ]..sort((a, b) => a.leftAt.compareTo(b.leftAt));
  final take = breakTaker(breaks);
  return [for (final e in sorted) ExitCheck(leftAt: e.leftAt, backAt: e.backAt, slot: take(e.leftAt))];
}
