import 'package:geolocator/geolocator.dart';

import '../../core/app_user.dart';
import '../../core/location.dart';
import '../notifications/notifications.dart' show peopleUnder;
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
// - drivers aren't asked: on the road 10 min after the end, their overtime
//   starts by itself and ends when they arrive home (`users.homeLocation`)
//   or at a work site (server, functions/attendance.js `driveStart` /
//   `driveEnd`); at a site or home they get none;
// - overtime is recorded at once and waits for a manager's approval
//   (Attendance page, Home card), who may change the minutes.

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
  if (day.overtimeDeclined != afterDecline) return false;
  if (!hours.days.contains(now.weekday)) return false;
  final end = DateTime(now.year, now.month, now.day).add(Duration(minutes: hours.endMinute));
  final from = day.checkInAt!.isAfter(end) ? day.checkInAt! : end;
  return !now.isBefore(end.add(overtimeAskAfter)) && now.isBefore(from.add(Duration(minutes: me.overtimeCapMin)));
}

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
/// managers for the people under them; never their own.
bool canApproveOvertime(AppUser me, AppUser person, List<AppUser> users) =>
    me.id != person.id && (me.role.canSeeHr || peopleUnder(me, users).any((u) => u.id == person.id));
