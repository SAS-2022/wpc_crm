import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/city_areas.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../clients/person_style.dart' show initialsOf;
import '../devices/device_status.dart';
import '../devices/phone_status_screen.dart' show PhoneCheckRow;
import '../devices/quiet_reason_text.dart';
import '../tracking/device_health.dart' show phoneBrand;
import '../tracking/phone_setup_guide.dart';
import '../home/app_shell.dart' show wideLayoutWidth;
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../notifications/notifications.dart' show peopleUnder;
import '../settings/page_access.dart';
import '../tracking/live_data.dart';
import '../tracking/live_map_screen.dart' show timeAgo;
import '../tracking/tracking_schedule.dart';
import '../tracking/work_hours.dart';
import '../users/companies.dart';
import '../users/company_filter.dart';
import '../users/users_repository.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonLabel;
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_correction.dart';
import 'attendance_day.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'site_now.dart';
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
enum _Filter { onSite, away, notIn, checkedOut, noAttendance }

/// One person on the map with everything the details show.
class _Person {
  _Person({
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

  _Filter get filter => switch (day?.status) {
        null => _Filter.noAttendance,
        DayStatus.onSite => _Filter.onSite,
        DayStatus.away => _Filter.away,
        DayStatus.checkedOut => _Filter.checkedOut,
        DayStatus.notIn || DayStatus.absent || DayStatus.onLeave => _Filter.notIn,
      };
}

Color _statusColor(BuildContext context, _Person p) => switch (p.day?.status) {
      null => Colors.blueGrey,
      DayStatus.onSite => Colors.green.shade700,
      DayStatus.away => Colors.orange.shade800,
      DayStatus.checkedOut => Colors.indigo,
      DayStatus.absent => Colors.deepOrange,
      DayStatus.onLeave => Colors.blue.shade400,
      // Not in yet after their start (+ grace): red.
      DayStatus.notIn => p.day!.notInYet ? Theme.of(context).colorScheme.error : Colors.grey.shade600,
    };

String _statusLabel(AppLocalizations l10n, _Person p) => switch (p.day?.status) {
      null => l10n.notOnAttendance,
      DayStatus.onSite => l10n.onSite,
      DayStatus.away => l10n.leftTheSite,
      DayStatus.checkedOut => l10n.checkedOutTitle,
      DayStatus.absent => l10n.reportedAbsent,
      DayStatus.onLeave => l10n.dayOnLeave,
      DayStatus.notIn => l10n.notCheckedIn,
    };

IconData _statusIcon(_Person p) => switch (p.day?.status) {
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
List<_Person> _people(WidgetRef ref, DateTime now) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final all = ref.watch(usersProvider).value ?? const <AppUser>[];
  final visible = me.role.canSeeHr ? all : peopleUnder(me, all);
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
  final recordedIds = [for (final u in users) if (!u.role.isLocationTracked && u.recordsGps) u.id]..sort();
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
        return _Person(
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
            shouldShare: (tracked || u.recordsGps) &&
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

class EmployeesMapScreen extends ConsumerStatefulWidget {
  const EmployeesMapScreen({super.key});

  @override
  ConsumerState<EmployeesMapScreen> createState() => _EmployeesMapScreenState();
}

class _EmployeesMapScreenState extends ConsumerState<EmployeesMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });
  Timer? _tick;
  bool _fitted = false;
  SaudiRegion? _region;
  String? _siteId;
  final _filters = <_Filter>{};
  String _query = '';

  /// The person shown in the right pane (web).
  String? _selected;

  @override
  void initState() {
    super.initState();
    // Keeps "5 min ago", live / old positions and "late" current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _refit() => _fitted = false;

  void _open(_Person p, bool wide) {
    if (p.loc != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.loc!.lat, p.loc!.lng), 16));
    }
    if (wide) {
      setState(() => _selected = p.user.id);
      return;
    }
    // Phones: a pop-up that keeps updating while open.
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _PersonDetails(uid: p.user.id, onClose: () => Navigator.pop(dialog)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final everyone = _people(ref, now);
    final region = _region;
    // A region (2026-11-04, user): its work sites only, and the companies of
    // the people there. A person is in it by their position, else (no
    // position yet) by a work site of theirs inside it.
    final activeSites = [for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) if (s.active) s];
    bool personIn(SaudiRegion? r, _Person p) =>
        r == null ||
        (p.loc != null
            ? r.contains(p.loc!.lat, p.loc!.lng)
            : activeSites.any((s) => p.user.workSiteIds.contains(s.id) && r.contains(s.lat, s.lng)));
    bool inRegion(_Person p) => personIn(region, p);
    final sites = [for (final s in activeSites) if (region == null || region.contains(s.lat, s.lng)) s];
    final site = sites.where((s) => s.id == _siteId).firstOrNull;
    final companyId = ref.watch(peopleCompanyProvider);
    final q = foldSearch(_query);
    // A site (2026-11-07): who is there now, plus those assigned to it who
    // are at no site now — not everyone assigned to it.
    bool underSite(_Person p) {
      if (site == null) return true;
      final at = siteNow(
        sites: activeSites,
        lat: p.loc?.lat,
        lng: p.loc?.lng,
        accuracy: p.loc?.accuracy,
        at: p.loc?.updatedAt,
        now: now,
        inside: p.result != null && p.result!.checkInAt != null && !p.result!.closed && p.result!.inside,
        events: p.record?.events ?? const [],
      );
      return showsUnderSite(site.id, now: at, assigned: p.user.workSiteIds);
    }

    // Company, site, region and search narrow everyone; the status chips
    // count those, then narrow further.
    final scoped = [
      for (final p in everyone)
        if ((companyId == null || p.user.companyId == companyId) &&
            underSite(p) &&
            inRegion(p) &&
            searchHas(p.user.name, q))
          p,
    ];
    final counts = {for (final f in _Filter.values) f: scoped.where((p) => p.filter == f).length};
    final shown = [for (final p in scoped) if (_filters.isEmpty || _filters.contains(p.filter)) p];
    // Located first, then by status, then by name.
    shown.sort((a, b) {
      if ((a.loc == null) != (b.loc == null)) return a.loc == null ? 1 : -1;
      if (a.filter != b.filter) return a.filter.index.compareTo(b.filter.index);
      return a.user.name.compareTo(b.user.name);
    });
    final located = [for (final p in shown) if (p.loc != null) p];
    final points = [for (final p in located) LatLng(p.loc!.lat, p.loc!.lng)];

    if (_map != null && !_fitted && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_map != null) fitPoints(_map!, points, padding: 48);
      });
    }

    final map = GoogleMap(
      initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 6),
      mapType: ref.watch(mapTypeProvider),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: (c) => setState(() => _map = c),
      circles: {
        for (final s in sites)
          Circle(
            circleId: CircleId('site_${s.id}'),
            center: LatLng(s.lat, s.lng),
            radius: s.radius,
            strokeWidth: s.id == _siteId ? 3 : 1,
            strokeColor: Colors.blue.shade700,
            fillColor: Colors.blue.withValues(alpha: s.id == _siteId ? 0.15 : 0.07),
          ),
      },
      markers: {
        for (final s in sites)
          Marker(
            markerId: MarkerId('site_${s.id}'),
            position: LatLng(s.lat, s.lng),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 0,
            icon: _icons.circle(context: context, fill: Colors.blue.shade700, text: '', ringWidth: 3, size: 18),
            infoWindow: InfoWindow(title: s.name),
          ),
        for (final p in located)
          Marker(
            markerId: MarkerId(p.user.id),
            position: LatLng(p.loc!.lat, p.loc!.lng),
            anchor: const Offset(0.5, 0.5),
            zIndexInt: p.user.id == _selected ? 3 : 2,
            icon: _icons.circle(
              context: context,
              // An older position: grey fill.
              fill: p.live ? Colors.white : Colors.grey.shade300,
              text: initialsOf(p.user.name),
              textColor: _statusColor(context, p),
              ring: p.user.id == _selected ? Colors.black : _statusColor(context, p),
              ringWidth: 4,
              size: p.user.id == _selected ? 46 : 40,
            ),
            onTap: () => _open(p, MediaQuery.sizeOf(context).width >= wideLayoutWidth),
          ),
      },
    );

    // Search, company, site and status filters (pane on the web, sheet on phones).
    List<Widget> filters() => [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchByName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _refit();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (f, color, label) in [
                  (_Filter.onSite, Colors.green.shade700, l10n.onSite),
                  (_Filter.away, Colors.orange.shade800, l10n.leftTheSite),
                  (_Filter.notIn, Colors.grey.shade600, l10n.notCheckedIn),
                  (_Filter.checkedOut, Colors.indigo, l10n.checkedOutTitle),
                  (_Filter.noAttendance, Colors.blueGrey, l10n.notOnAttendance),
                ])
                  if (counts[f]! > 0 || _filters.contains(f))
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.circle, size: 12, color: color),
                      label: Text('$label (${counts[f]})'),
                      selected: _filters.contains(f),
                      showCheckmark: false,
                      onSelected: (on) => setState(() {
                        on ? _filters.add(f) : _filters.remove(f);
                        _refit();
                      }),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              [l10n.employeesCount(shown.length), l10n.employeesMapNote].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ];

    List<Widget> rows(bool wide) => [
          if (shown.isEmpty) ListTile(title: Text(l10n.noOneMatches)),
          for (final p in shown)
            ListTile(
              selected: p.user.id == _selected,
              leading: _Avatar(name: p.user.name, color: _statusColor(context, p), faded: !p.live),
              title: Text(p.user.name),
              subtitle: Text(
                [_rowLine(context, l10n, p), p.siteName].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: p.report.problemCount > 0
                  ? Tooltip(
                      message: p.report.quiet != null
                          ? quietLine(context, p.report.quiet!, p.report.lastPosition, DateTime.now())
                          : l10n.phoneStatusProblems(p.report.problemCount),
                      child: Icon(Icons.phonelink_erase, color: theme.colorScheme.error, size: 20),
                    )
                  : null,
              onTap: () => _open(p, wide),
            ),
        ];

    // Over the map, top left (user 2026-11-04): regions, then companies,
    // then work sites, each row under a separator.
    final allCompanies = ref.watch(companiesProvider).value ?? const <Company>[];
    final regionCompanyIds = {for (final p in everyone) if (inRegion(p)) p.user.companyId};
    final companies = [
      for (final c in allCompanies)
        if (region == null || regionCompanyIds.contains(c.id) || c.id == companyId) c,
    ];
    void pickSite(WorkSite? s) => setState(() {
          _siteId = s?.id;
          if (s == null) {
            _refit();
          } else {
            _fitted = true;
            _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(s.lat, s.lng), 16));
          }
        });
    Widget chipRow(IconData icon, List<Widget> chips) => Row(children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: c),
              ]),
            ),
          ),
        ]);
    Widget choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          visualDensity: VisualDensity.compact,
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        );
    final regionChips = PositionedDirectional(
      top: 8,
      start: 8,
      end: 64,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          // Wider (user 2026-11-07).
          constraints: const BoxConstraints(maxWidth: 720),
          child: PointerInterceptor(
            child: Material(
              elevation: 3,
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    chipRow(Icons.explore_outlined, [
                      for (final r in SaudiRegion.values)
                        choice(r.label(l10n), region == r, () {
                          final next = region == r ? null : r;
                          // A site or company with nothing in the new region
                          // would leave the map empty: drop it.
                          final siteNow = activeSites.where((s) => s.id == _siteId).firstOrNull;
                          if (next != null && siteNow != null && !next.contains(siteNow.lat, siteNow.lng)) _siteId = null;
                          if (next != null &&
                              companyId != null &&
                              !everyone.any((p) => p.user.companyId == companyId && personIn(next, p))) {
                            ref.read(peopleCompanyProvider.notifier).set(null);
                          }
                          setState(() {
                            _region = next;
                            _refit();
                          });
                        }),
                    ]),
                    if (allCompanies.length > 1 && companies.isNotEmpty) ...[
                      const Divider(height: 10),
                      chipRow(Icons.business, [
                        choice(l10n.allCompanies, companyId == null, () {
                          ref.read(peopleCompanyProvider.notifier).set(null);
                          setState(_refit);
                        }),
                        for (final c in companies)
                          choice(c.name, companyId == c.id, () {
                            ref.read(peopleCompanyProvider.notifier).set(companyId == c.id ? null : c.id);
                            setState(_refit);
                          }),
                      ]),
                    ],
                    if (sites.isNotEmpty) ...[
                      const Divider(height: 10),
                      chipRow(Icons.place_outlined, [
                        choice(l10n.allSites, site == null, () => pickSite(null)),
                        for (final s in sites) choice(s.name, site?.id == s.id, () => pickSite(site?.id == s.id ? null : s)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget fitButton(double bottom) => PositionedDirectional(
          end: 12,
          bottom: bottom,
          child: PointerInterceptor(
            child: FloatingActionButton.small(
              heroTag: 'employeesFit',
              tooltip: l10n.showEveryone,
              onPressed: points.isEmpty ? null : () => fitPoints(_map!, points, padding: 48),
              child: const Icon(Icons.zoom_out_map),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeesMap)),
      body: LayoutBuilder(builder: (context, c) {
        final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
        if (wide) {
          final selected = everyone.any((p) => p.user.id == _selected) ? _selected : null;
          return Row(
            children: [
              Expanded(
                child: Stack(children: [
                  map,
                  const PositionedDirectional(top: 8, end: 8, child: MapTypeButton()),
                  regionChips,
                  fitButton(16),
                ]),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: c.maxWidth >= 1300 ? 420 : 360,
                child: selected != null
                    ? _PersonDetails(
                        key: ValueKey(selected),
                        uid: selected,
                        onClose: () => setState(() => _selected = null),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 24),
                        children: [...filters(), const Divider(), ...rows(true)],
                      ),
              ),
            ],
          );
        }
        final sheetTop = c.maxHeight * 0.32;
        return Stack(children: [
          Padding(padding: EdgeInsets.only(bottom: sheetTop - 16), child: map),
          const PositionedDirectional(top: 8, end: 8, child: MapTypeButton()),
          regionChips,
          fitButton(sheetTop + 8),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            builder: (context, scroll) => PointerInterceptor(
              child: Material(
                elevation: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    ...filters(),
                    const Divider(),
                    ...rows(false),
                  ],
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// The list row's line: status, check-in time, late.
String _rowLine(BuildContext context, AppLocalizations l10n, _Person p) {
  final time = DateFormat.jm(Localizations.localeOf(context).toString());
  final d = p.result;
  final day = p.day;
  return [
    _statusLabel(l10n, p),
    if (d?.checkInAt != null) l10n.inSince(time.format(d!.checkInAt!)),
    if (day != null && day.lateMin > 0) l10n.lateBy(formatMinutes(day.lateMin)),
    if (p.loc == null) l10n.locationNotShared,
  ].join(' · ');
}

/// A person's details: attendance today, position, phone. The web's right
/// pane and the phones' pop-up; watches the data itself so it stays current.
class _PersonDetails extends ConsumerWidget {
  const _PersonDetails({super.key, required this.uid, required this.onClose});

  final String uid;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final p = _people(ref, now).where((p) => p.user.id == uid).firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final me = ref.watch(currentUserProvider).value;
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    final company = ref.watch(companyNamesProvider)[p.user.companyId];
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    final u = p.user;
    final d = p.result;
    final day = p.day;
    final color = _statusColor(context, p);
    final green = Colors.green.shade700;
    final error = theme.colorScheme.error;
    final midnight = DateTime(now.year, now.month, now.day);
    final workDay = p.schedule.days.contains(now.weekday);

    Widget section(String title, IconData icon, List<Widget> children) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ]),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        );
    Widget line(String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: bold ? FontWeight.w600 : null)),
        );

    // Attendance today.
    final attendance = <Widget>[
      if (day == null)
        line(l10n.notOnAttendance, color: theme.colorScheme.outline)
      else ...[
        Row(children: [
          Icon(_statusIcon(p), size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(_statusLabel(l10n, p), style: theme.textTheme.titleMedium?.copyWith(color: color))),
          if (day.workedMin > 0) Text(formatMinutes(day.workedMin), style: theme.textTheme.titleSmall),
        ]),
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
              line(l10n.siteTripLine(
              time.format(t.leftAt),
              time.format(t.backAt),
              formatMinutes(t.backAt.difference(t.leftAt).inMinutes),
            )),
          if (d.checkOutAt != null && d.closed)
            line([l10n.checkedOutAt(time.format(d.checkOutAt!)), checkOutTypeLabel(l10n, d.checkOutType)]
                .where((s) => s.isNotEmpty)
                .join(' · ')),
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
              canCorrect: me?.role.canManageHr ?? false,
              canOpenUser: me?.role.isAdmin ?? false,
            ),
          ),
        ),
      ],
    ];

    // Position.
    final loc = p.loc;
    final location = <Widget>[
      if (loc == null)
        line(u.role.isLocationTracked ? l10n.noLocationYet : l10n.noPositionRecordedToday,
            color: theme.colorScheme.outline)
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
      if (r.quiet != null)
        line(quietLine(context, r.quiet!, r.lastPosition, now), color: error, bold: true),
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
        line(l10n.phoneStatusApp(u.appVersions.values.map((v) => v.label).join(', ')), color: theme.colorScheme.outline),
    ];

    final canRoute = me != null &&
        access.allowsUser(me, AppPage.routeHistory) &&
        (me.role.isSupervisor || (me.role.seesDrivers && u.role.isDriver));

    return Material(
      color: theme.colorScheme.surface,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(
              children: [
                _Avatar(name: u.name, color: color, faded: !p.live),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: theme.textTheme.titleLarge),
                      Text([u.role.label(l10n), ?company].join(' · '), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
          ),
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
                    onPressed: () {
                      // Close the pop-up on phones before leaving the page.
                      if (MediaQuery.sizeOf(context).width < wideLayoutWidth) onClose();
                      context.push('/history?uid=${u.id}');
                    },
                    icon: const Icon(Icons.route),
                    label: Text(l10n.routeHistoryToday),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.faded});

  final String name;
  final Color color;

  /// An older position (or none): grey fill, as on the map.
  final bool faded;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: faded ? Colors.grey.shade300 : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
        alignment: Alignment.center,
        child: Text(initialsOf(name), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      );
}
