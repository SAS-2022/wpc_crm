import 'package:geolocator/geolocator.dart';

import '../../core/app_user.dart';
import '../../core/location.dart';
import '../notifications/notifications.dart' show departmentHeadsOf, directManagersOf, peopleUnder;
import '../tracking/work_hours.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';

// Overtime has to be started (user decisions 2026-10-25):
// - site staff with overtime allowed who are still at the site 10 minutes
//   after their work day ends get "Start overtime?" (push with its own
//   sound + a pop-up when the app opens; reminded once after 30 min). Only
//   "Start overtime" makes the time after the end count — from the end,
//   whenever they confirm (still at the site). "Not today" stops the asking;
// - drivers aren't asked (rules 2026-10-27, server functions/attendance.js
//   `driveDecide` / `driveEnd`): at a work site or home at the end → none,
//   also when they drive home afterwards; still driving at the end → none if
//   they get home within App setting `driveHomeGraceMin` (30 min, the drive
//   home), else overtime from the end until they arrive at a work site or
//   home (`users.homeLocation`, which drivers are asked to set);
// - overtime is recorded at once and waits for a manager's approval
//   (Attendance page, Home card), who may change the minutes or reject it.

/// "Start overtime?" is asked this long after the end (same as ASK_AFTER_MS).
const overtimeAskAfter = Duration(minutes: 10);

/// Whether [me] should be asked "Start overtime?" now ([day]: today's result,
/// [hours]: their schedule). Same conditions as `overtimeAskDue` on the
/// server, without the reminder timing. [afterDecline]: whether they may
/// still start it after "Not today" (pressed by mistake; 2026-10-25, the
/// card keeps a "Start overtime" button — a later otStart still counts).
bool overtimeQuestionPending(AppUser me, DayResult? day, WorkHours hours, DateTime now, {bool afterDecline = false}) {
  if (!me.overtimeAllowed || me.role == UserRole.driver || day == null) return false;
  if (!day.checkedIn || day.closed || !day.inside || day.overtimeConfirmedAt != null) return false;
  // Overtime already on (e.g. an overtime day a manager allowed, 2026-11-08).
  if (day.overtimeOn) return false;
  if (day.overtimeDeclined != afterDecline) return false;
  if (!hours.days.contains(now.weekday)) return false;
  final end = DateTime(now.year, now.month, now.day).add(Duration(minutes: hours.endMinute));
  final from = day.checkInAt!.isAfter(end) ? day.checkInAt! : end;
  return !now.isBefore(end.add(overtimeAskAfter)) && now.isBefore(from.add(Duration(minutes: me.overtimeCapMin)));
}

/// Overtime away from the work sites (2026-11-21, server `fieldOvertime`):
/// what to ask the person now. [confirm]: it's running from the end (they
/// weren't home) — "Yes, I'm working" / "I'm not working"; [start]: no home
/// location, it runs only once they start it.
enum FieldOvertimeAsk { none, confirm, start }

FieldOvertimeAsk fieldOvertimeQuestion(AttendanceRecord? record, DateTime now, int capMin) {
  final drive = record?.drive;
  if (drive == null || !drive.field || drive.confirmed) return FieldOvertimeAsk.none;
  // Answered on this phone (the server catches up within 10 min).
  final from = drive.startAt.subtract(overtimeAskAfter);
  final answered = record!.events.any((e) =>
      (e.type == AttendanceEventType.otStart || e.type == AttendanceEventType.otDecline) && !e.at.isBefore(from));
  if (answered) return FieldOvertimeAsk.none;
  if (drive.running) return FieldOvertimeAsk.confirm;
  if (drive.asked && now.isBefore(drive.startAt.add(Duration(minutes: capMin)))) return FieldOvertimeAsk.start;
  return FieldOvertimeAsk.none;
}

/// "Yes, I'm working" / "Start overtime" away from the site: no site check.
Future<void> confirmFieldOvertime(AppUser me) => recordAttendance(me.id, AttendanceEventType.otStart, extra: {'field': true});

enum StartOvertimeResult { started, notAtSite }

/// "Start overtime": a GPS fix must not put them clearly away from their
/// sites (no fix / a rough one: allowed, the site checks follow).
Future<StartOvertimeResult> startOvertime(AppUser me, List<WorkSite> sites) async {
  final mine = [
    for (final s in sites)
      if (s.active && me.workSiteIds.contains(s.id)) s,
  ];
  final fix = (await currentPosition()).position;
  Map<String, Object>? extra;
  String? siteId;
  if (fix != null && mine.isNotEmpty) {
    double distanceTo(WorkSite s) => Geolocator.distanceBetween(fix.latitude, fix.longitude, s.lat, s.lng);
    mine.sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
    final site = mine.first;
    final distance = distanceTo(site);
    if (siteCheckResult(distance: distance, accuracy: fix.accuracy, radius: site.radius) == SiteCheckResult.gone) {
      return StartOvertimeResult.notAtSite;
    }
    siteId = site.id;
    extra = {'dist': distance.round(), 'acc': fix.accuracy.round()};
  }
  await recordAttendance(me.id, AttendanceEventType.otStart, siteId: siteId, extra: extra);
  return StartOvertimeResult.started;
}

/// "Not today": no more asking today.
Future<void> declineOvertime(AppUser me) => recordAttendance(me.id, AttendanceEventType.otDecline);

/// Whether [me] approves [person]'s overtime: the HR area for everyone,
/// managers for the people under them (direct reports and, for a
/// department head, the whole department); never their own.
bool canApproveOvertime(AppUser me, AppUser person, List<AppUser> users) =>
    me.id != person.id && (me.can.canSeeHr || peopleUnder(me, users).any((u) => u.id == person.id));

/// Whether [me] decides if [person] earns overtime (user request
/// 2026-11-05, Attendance → Overtime permission; off = time after the end of
/// the work day never counts): the sales manager / GM for everyone, HR for
/// the roles they manage, a manager for the people whose department they
/// head or whose direct manager they are; never themselves. The rules allow
/// the same (same department, chosen manager, or the roles they manage).
bool canSetOvertimeFor(AppUser me, AppUser person, List<AppUser> users) {
  if (person.id == me.id || !person.active || !me.active) return false;
  if (me.can.isAdmin) return true;
  if (me.hasRole(UserRole.hr)) return UserRole.hrManagedRoles.contains(person.role);
  // Warehouse supervisors their own people, the logistics manager every
  // driver (2026-11-25, user).
  if (person.supervisorId == me.id) return true;
  if (me.can.managesDrivers && person.role.isDriver) return true;
  if (!me.isManager) return false;
  return departmentHeadsOf(person, users).contains(me.id) || directManagersOf(person, users).contains(me.id);
}
