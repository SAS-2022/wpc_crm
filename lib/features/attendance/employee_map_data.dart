
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../devices/device_status.dart';
import '../devices/phone_status_screen.dart' show PhoneCheckRow;
import '../devices/quiet_reason_text.dart';
import '../tracking/device_health.dart' show phoneBrand;
import '../tracking/phone_setup_guide.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../notifications/notifications.dart' show peopleUnder;
import '../settings/page_access.dart';
import '../tracking/live_data.dart';
import '../../core/time_ago.dart';
import '../tracking/tracking_schedule.dart';
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonLabel;
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_correction.dart';
import 'attendance_day.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'break_widgets.dart';
import 'work_sites.dart';

// Employees map (user request 2026-11-04): opened from the Attendance page,
// apart from the clients map — only employees: where everyone on the
// attendance page is now, pins coloured by today's attendance (on site, left
// the site, not checked in, checked out). Filters: region (Eastern / Central
// / Western), company, work site (also zooms to it), status. Tapping a person
// shows their details — attendance today (check-in time, late or on time),
// position and phone state — in a pane on the right on the web, in a pop-up
// on phones. Positions: `live_locations` for the location-tracked roles,
// today's last `location_history` point for staff whose GPS is recorded for
// attendance. Readable by KAM / SM / GM / logistics manager (RTDB rules).

/// The status filter chips.
enum EmployeeFilter { onSite, away, notIn, checkedOut, noAttendance }

/// One person on the map with everything the details show.
class EmployeeOnMap {
  EmployeeOnMap({
    required this.user,
    required this.loc,
    required this.live,
    required this.day,
    required this.result,
    required this.record,
    required this.absence,
    required this.leave,
    required this.report,
    required this.siteName,
    required this.schedule,
  });

  final AppUser user;
  final LiveLocation? loc;

  /// [loc] is from the last few minutes.
  final bool live;

  /// Null = attendance isn't recorded for them.
  final PersonDay? day;
  final DayResult? result;
  final AttendanceRecord? record;
  final Absence? absence;
  final LeaveRequest? leave;
  final PhoneReport report;
  final String siteName;
  final WorkHours schedule;

  EmployeeFilter get filter => switch (day?.status) {
    null => EmployeeFilter.noAttendance,
    DayStatus.onSite => EmployeeFilter.onSite,
    DayStatus.away => EmployeeFilter.away,
    DayStatus.checkedOut => EmployeeFilter.checkedOut,
    DayStatus.notIn || DayStatus.absent || DayStatus.onLeave => EmployeeFilter.notIn,
  };
}

Color employeeStatusColor(BuildContext context, EmployeeOnMap p) => switch (p.day?.status) {
  null => Colors.blueGrey,
  DayStatus.onSite => Colors.green.shade700,
  DayStatus.away => Colors.orange.shade800,
  DayStatus.checkedOut => Colors.indigo,
  DayStatus.absent => Colors.deepOrange,
  DayStatus.onLeave => Colors.blue.shade400,
  // Not in yet after their start (+ grace): red.
  DayStatus.notIn => p.day!.notInYet ? Theme.of(context).colorScheme.error : Colors.grey.shade600,
};

String employeeStatusLabel(AppLocalizations l10n, EmployeeOnMap p) => switch (p.day?.status) {
  null => l10n.notOnAttendance,
  DayStatus.onSite => l10n.onSite,
  DayStatus.away => l10n.leftTheSite,
  DayStatus.checkedOut => l10n.checkedOutTitle,
  DayStatus.absent => l10n.reportedAbsent,
  DayStatus.onLeave => l10n.dayOnLeave,
  DayStatus.notIn => l10n.notCheckedIn,
};

IconData _statusIcon(EmployeeOnMap p) => switch (p.day?.status) {
  null => Icons.person_outline,
  DayStatus.onSite => Icons.how_to_reg,
  DayStatus.away => Icons.directions_walk,
  DayStatus.checkedOut => Icons.logout,
  DayStatus.absent => Icons.sick_outlined,
  DayStatus.onLeave => Icons.beach_access,
  DayStatus.notIn => p.day!.notInYet ? Icons.hourglass_bottom : Icons.person_off_outlined,
};

/// Everyone [me] may see on the map (the Attendance page's people: HR area
/// everyone, other managers the people under them) whose phone shares or
/// records a position, or whose attendance is recorded.
List<EmployeeOnMap> employeePeople(WidgetRef ref, DateTime now) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final all = ref.watch(usersProvider).value ?? const <AppUser>[];
  final visible = me.can.canSeeHr ? all : peopleUnder(me, all);
  final users = [
    for (final u in visible)
      if (u.active &&
          u.role != UserRole.unknown &&
          u.role.value.isNotEmpty &&
          (u.role.isLocationTracked || u.recordsGps || u.checksAttendance))
        u,
  ]..sort((a, b) => a.name.compareTo(b.name));

  final dayKey = attendanceDay(now);
  final midnight = DateTime(now.year, now.month, now.day);
  final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
  final siteNames = {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s.name};
  final live = ref.watch(liveLocationsProvider).value ?? const <String, LiveLocation>{};
  final presence = ref.watch(presenceProvider).value ?? const <String, Presence>{};
  final recordedIds = [
    for (final u in users)
      if (!u.role.isLocationTracked && u.recordsGps) u.id,
  ]..sort();
  final recorded = recordedIds.isEmpty
      ? const <String, LiveLocation>{}
      : ref.watch(recordedLocationsProvider((dayKey, recordedIds.join(',')))).value ?? const <String, LiveLocation>{};
  final devices = ref.watch(deviceStatusesProvider).value ?? const <String, DeviceStatus>{};
  final schedules = ref.watch(trackingSchedulesProvider).value ?? const <String, TrackingSchedule>{};
  final records = ref.watch(dayAttendanceProvider(dayKey)).value ?? const <String, AttendanceRecord>{};
  final absences = ref.watch(dayAbsencesProvider(dayKey)).value ?? const <String, Absence>{};
  final leave = {
    for (final r in ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[])
      if (r.isLeave &&
          r.status == LeaveStatus.approved &&
          r.from != null &&
          r.to != null &&
          r.from!.compareTo(dayKey) <= 0 &&
          r.to!.compareTo(dayKey) >= 0)
        r.uid: r,
  };

  return [
    for (final u in users)
      () {
        final tracked = u.role.isLocationTracked;
        final loc = tracked ? live[u.id] : recorded[u.id];
        final state = tracked ? liveState(loc, presence[u.id], now) : recordedState(loc, now);
        final result = u.checksAttendance ? records[u.id]?.best(u, company) : null;
        final schedule = u.scheduleOr(company);
        return EmployeeOnMap(
          user: u,
          loc: loc,
          live: state == LiveState.live,
          day: u.checksAttendance
              ? personDay(
                  result,
                  schedule: schedule,
                  overtimeAllowed: u.overtimeAllowed,
                  overtimeMaxMin: u.overtimeCapMin,
                  day: midnight,
                  now: now,
                  reportedAbsent: absences.containsKey(u.id),
                  onLeave: leave.containsKey(u.id),
                )
              : null,
          result: result,
          record: records[u.id],
          absence: absences[u.id],
          leave: leave[u.id],
          report: phoneReport(
            device: devices[u.id],
            presence: presence[u.id],
            liveAt: live[u.id]?.updatedAt,
            recordedAt: recorded[u.id]?.updatedAt,
            versions: u.appVersions,
            shouldShare:
                (tracked || u.recordsGps) &&
                (schedules[u.id] ?? const TrackingSchedule.standard()).isOn(
                  now,
                  company,
                  driver: u.role.isDriver,
                  recordOnly: u.recordsGps,
                  days: u.workSchedule?.days,
                ),
            now: now,
          ),
          siteName: siteNames[result?.siteId] ?? u.workSiteIds.map((id) => siteNames[id]).nonNulls.firstOrNull ?? '',
          schedule: schedule,
        );
      }(),
  ];
}

/// The list row's line: status, check-in time, late.
String employeeRowLine(BuildContext context, AppLocalizations l10n, EmployeeOnMap p) {
  final time = DateFormat.jm(Localizations.localeOf(context).toString());
  final d = p.result;
  final day = p.day;
  return [
    employeeStatusLabel(l10n, p),
    if (d?.checkInAt != null) l10n.inSince(time.format(d!.checkInAt!)),
    if (day != null && day.lateMin > 0) l10n.lateBy(formatMinutes(day.lateMin)),
    if (p.loc == null) l10n.locationNotShared,
  ].join(' · ');
}

/// A person's details: attendance today, position, phone (people map's pane /
/// phone sheet in Employee Map mode); watches the data itself so it stays current.
class EmployeeDetails extends ConsumerWidget {
  const EmployeeDetails({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final p = employeePeople(ref, now).where((p) => p.user.id == uid).firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final me = ref.watch(currentUserProvider).value;
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    final u = p.user;
    final d = p.result;
    final day = p.day;
    final color = employeeStatusColor(context, p);
    final green = Colors.green.shade700;
    final error = theme.colorScheme.error;
    final midnight = DateTime(now.year, now.month, now.day);
    final workDay = p.schedule.days.contains(now.weekday);

    Widget section(String title, IconData icon, List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : null),
      ),
    );

    // Attendance today.
    final attendance = <Widget>[
      if (day == null)
        line(l10n.notOnAttendance, color: theme.colorScheme.outline)
      else ...[
        Row(
          children: [
            Icon(_statusIcon(p), size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(employeeStatusLabel(l10n, p), style: theme.textTheme.titleMedium?.copyWith(color: color)),
            ),
            if (day.workedMin > 0) Text(formatMinutes(day.workedMin), style: theme.textTheme.titleSmall),
          ],
        ),
        if (p.siteName.isNotEmpty) line(l10n.siteName(p.siteName)),
        if (workDay) line(l10n.startAt(time.format(midnight.add(Duration(minutes: p.schedule.startMinute))))),
        if (d?.checkInAt != null) ...[
          line(l10n.checkedInAtTime(time.format(d!.checkInAt!)), bold: true),
          day.lateMin > 0
              ? line(l10n.lateByLong(formatMinutes(day.lateMin)), color: error, bold: true)
              : line(l10n.onTime, color: green, bold: true),
          if (day.status == DayStatus.away && d.lastExitAt != null) line(l10n.leftSiteAt(time.format(d.lastExitAt!))),
          if (u.requestsBreaks)
            for (final c in personExitChecks(u, p.record, d, ref.watch(workHoursProvider).value ?? WorkHours.defaults))
              line(exitCheckLine(l10n, time, c, today: true), color: exitCheckColor(context, c, today: true))
          else
            for (final t in p.record?.trips ?? const <SiteTrip>[])
              line(
                l10n.siteTripLine(
                  time.format(t.leftAt),
                  time.format(t.backAt),
                  formatMinutes(t.backAt.difference(t.leftAt).inMinutes),
                ),
              ),
          if (d.checkOutAt != null && d.closed)
            line(
              [
                l10n.checkedOutAt(time.format(d.checkOutAt!)),
                checkOutTypeLabel(l10n, d.checkOutType),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
          if (day.workedMin > 0) line('${l10n.workedSoFar}: ${formatMinutes(day.workedMin)}'),
        ] else if (day.notInYet)
          line(l10n.lateByLong(formatMinutes(day.lateMin)), color: error, bold: true),
        if (p.absence != null)
          line([absenceReasonLabel(l10n, p.absence!.reason), p.absence!.note].where((s) => s.isNotEmpty).join(' · ')),
        if (p.leave != null) line(p.leave!.typeName(Localizations.localeOf(context).languageCode)),
        if (p.record?.correction != null) line(l10n.correctedByHr, color: theme.colorScheme.outline),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: Text(l10n.attendance),
            onPressed: () => showAttendanceDaySheet(
              context,
              person: u,
              day: midnight,
              record: p.record,
              result: d,
              absence: p.absence,
              canCorrect: me?.can.canManageHr ?? false,
              canOpenUser: me?.can.isAdmin ?? false,
            ),
          ),
        ),
      ],
    ];

    // Position.
    final loc = p.loc;
    final location = <Widget>[
      if (loc == null)
        line(
          u.role.isLocationTracked ? l10n.noLocationYet : l10n.noPositionRecordedToday,
          color: theme.colorScheme.outline,
        )
      else ...[
        line(
          p.live
              ? l10n.liveUpdated(timeAgo(context, loc.updatedAt, now))
              : l10n.lastPositionRecorded(timeAgo(context, loc.updatedAt, now)),
          color: p.live ? green : Colors.orange.shade800,
          bold: true,
        ),
        if (loc.accuracy != null) line(l10n.locationAccuracy(loc.accuracy!.round())),
        if (loc.mocked) line(l10n.mockedLocationWarning, color: error, bold: true),
      ],
    ];

    // Phone.
    final r = p.report;
    final s = r.status;
    final heard = r.lastHeard == null ? null : timeAgo(context, r.lastHeard, now);
    final phone = <Widget>[
      if (r.quiet != null) line(quietLine(context, r.quiet!, r.lastPosition, now), color: error, bold: true),
      line(
        switch (r.signal) {
          PhoneSignal.noPhone => l10n.phoneStatusNoPhone,
          PhoneSignal.stopped => heard == null ? l10n.phoneStatusStoppedNever : l10n.phoneStatusStopped(heard),
          PhoneSignal.recent || PhoneSignal.quiet => l10n.phoneStatusLastHeard(heard ?? '–'),
        },
        color: switch (r.signal) {
          PhoneSignal.stopped => error,
          PhoneSignal.recent => green,
          PhoneSignal.quiet => Colors.orange.shade800,
          PhoneSignal.noPhone => theme.colorScheme.outline,
        },
        bold: true,
      ),
      if (s != null) ...[
        // Stopped: these are the last report's values (2026-11-07).
        r.stopped && r.lastHeard != null
            ? line(l10n.phoneChecksFromLastReport(timeAgo(context, r.lastHeard, now)), color: theme.colorScheme.outline)
            : line(
                s.problems.isNotEmpty ? l10n.phoneStatusProblems(s.problems.length) : l10n.phoneStatusAllGood,
                color: s.problems.isNotEmpty ? error : green,
              ),
        const SizedBox(height: 4),
        for (final check in s.checks)
          if (!r.fromOldApp || s.state(check) != CheckState.unknown) PhoneCheckRow(status: s, check: check),
        if (s.app != null || s.phoneLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [if (s.app != null) l10n.phoneStatusApp(s.app!), ?s.phoneLabel].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        if (r.fromOldApp) line(l10n.phoneStatusOldApp, color: theme.colorScheme.outline),
        if (s.android)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => showPhoneSetupGuide(context, phoneBrand(s.maker ?? '')),
              icon: const Icon(Icons.list_alt, size: 18),
              label: Text(l10n.phoneSetupShowSteps),
            ),
          ),
      ] else if (u.appVersions.isNotEmpty)
        line(
          l10n.phoneStatusApp(u.appVersions.values.map((v) => v.label).join(', ')),
          color: theme.colorScheme.outline,
        ),
    ];

    final canRoute =
        me != null &&
        access.allowsUser(me, AppPage.routeHistory) &&
        (me.can.isSupervisor || (me.can.seesDrivers && u.role.isDriver));

    // Name, role and the close button are drawn by the people map's pane.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(l10n.attendanceToday, Icons.how_to_reg_outlined, attendance),
          section(l10n.locationTitle, Icons.location_on_outlined, location),
          section(l10n.phoneStatus, Icons.phone_android, phone),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (u.phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${u.phone}')),
                    icon: const Icon(Icons.phone),
                    label: Text(l10n.callPhone),
                  ),
                if (loc != null)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.directions),
                    label: Text(l10n.openInMaps),
                  ),
                if (canRoute)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/history?uid=${u.id}'),
                    icon: const Icon(Icons.route),
                    label: Text(l10n.routeHistoryToday),
                  ),
              ],
            ),
          ),
        ],
    );
  }
}
