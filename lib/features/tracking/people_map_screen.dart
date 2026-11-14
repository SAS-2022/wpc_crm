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
import '../../core/time_ago.dart';
import '../../l10n/app_localizations.dart';
import '../attendance/employee_map_data.dart';
import '../attendance/site_markers.dart';
import '../attendance/site_now.dart';
import '../attendance/work_sites.dart';
import '../clients/client_tags.dart';
import '../clients/clients_map_screen.dart' show managerPinColor;
import '../clients/person_style.dart';
import '../devices/device_status.dart';
import '../devices/quiet_reason_text.dart';
import '../home/app_shell.dart' show wideLayoutWidth;
import '../hr/hr_people.dart' show departmentsProvider;
import '../notifications/notifications.dart' show peopleUnder;
import '../reports/route_day.dart';
import '../users/companies.dart';
import '../users/company_filter.dart';
import '../users/people_filter.dart';
import '../users/users_repository.dart';
import 'live_data.dart';
import 'motion.dart';
import 'tracking_schedule.dart';
import 'work_hours.dart';

// One people map for Live tracking, Drivers, Route history and the Employee
// Map (user 2026-11-11: "they could all be the same with a few different
// functions for each"). Shared: the map, the filter card (regions, companies,
// sites), the list / details pane on the right (web) or the sheet (phones),
// selecting a person and the ✕ next to their name that goes back to the list.
// Per mode:
// - live / drivers: live positions, Sales team / Drivers / Other employees;
//   a person's details = live state, Call, Open in Maps, Route history.
// - history: the same people plus department chips; a person's details = their
//   route of the day (drawn on the map), day arrows, visits, time split.
// - employees: the Attendance page's people coloured by today's attendance,
//   status chips; details = attendance, position, phone.

enum PeopleMapMode { live, drivers, history, employees }

/// Live tracking's groups (drivers apart 2026-10-20, other employees 2026-11-01).
enum _Group { sales, drivers, staff }

/// A person as the map and the list show them, whatever the mode.
class _Pin {
  const _Pin({
    required this.user,
    required this.loc,
    required this.color,
    required this.line,
    this.fill = Colors.white,
    this.textColor,
    this.faded = false,
    this.mocked = false,
    this.trailing,
    this.siteNow,
    this.order = 0,
    this.status,
  });

  final AppUser user;
  final LiveLocation? loc;

  /// State colour: ring and initials.
  final Color color;
  final String line;
  final Color fill;
  final Color? textColor;

  /// An older position (or none): grey, as on the map.
  final bool faded;
  final bool mocked;
  final Widget? trailing;

  /// The work site they're at now (for the site filter).
  final String? siteNow;

  /// Sort key before the name.
  final int order;

  /// Employee Map: the status chip they count under.
  final EmployeeFilter? status;
}

class PeopleMapScreen extends ConsumerStatefulWidget {
  const PeopleMapScreen({super.key, required this.mode, this.onlyIds, this.personId, this.date});

  final PeopleMapMode mode;

  /// Opened from Phone status with a search or "Problems only" on: just the
  /// people that page showed (`/live?ids=a,b`; user 2026-11-02).
  final Set<String>? onlyIds;

  /// Route history: the person (`/history?uid=`) and day ('yyyy-MM-dd') to open.
  final String? personId;
  final String? date;

  @override
  ConsumerState<PeopleMapScreen> createState() => _PeopleMapScreenState();
}

class _PeopleMapScreenState extends ConsumerState<PeopleMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  }, zoom: 6);
  Timer? _tick;
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  final _route = RouteDay();

  /// What the map was last fitted to.
  String? _fitKey;

  SaudiRegion? _region;
  String? _siteId;
  String _query = '';
  _Group _group = _Group.sales;
  bool _groupPicked = false;
  late Set<String>? _onlyIds = widget.onlyIds;

  /// Route history: department id, '' = no department, null = all.
  String? _department;

  /// Employee Map status chips.
  final _statuses = <EmployeeFilter>{};

  /// The person whose details are open (pane / sheet).
  late String? _selected = widget.personId;
  late DateTime _day = _parseDay(widget.date);

  static DateTime _parseDay(String? s) {
    final now = DateTime.now();
    return DateTime.tryParse(s ?? '') ?? DateTime(now.year, now.month, now.day);
  }

  bool get _history => widget.mode == PeopleMapMode.history;
  bool get _employees => widget.mode == PeopleMapMode.employees;

  @override
  void initState() {
    super.initState();
    // Keeps "5 min ago", live / old positions and "late" current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(PeopleMapScreen old) {
    super.didUpdateWidget(old);
    // Opened again with another person or day (e.g. from the Visits list).
    if (widget.personId != old.personId || widget.date != old.date) {
      _selected = widget.personId;
      _day = _parseDay(widget.date);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _map?.dispose();
    _sheet.dispose();
    _search.dispose();
    super.dispose();
  }

  /// A filter changed: back to the list (the person may not be in it).
  void _filtered(VoidCallback change) => setState(() {
    change();
    _selected = null;
  });

  void _select(_Pin p, bool wide) {
    setState(() => _selected = p.user.id);
    if (!_history && p.loc != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.loc!.lat, p.loc!.lng), 16));
    }
    if (!wide && _sheet.isAttached) {
      _sheet.animateTo(0.5, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Color _liveColor(LiveState s) => switch (s) {
    LiveState.live => Colors.green.shade600,
    LiveState.stale => Colors.orange.shade700,
    LiveState.offDuty => Colors.blueGrey,
    LiveState.offline => Colors.grey,
  };

  /// "Driving", "Walking", "Idle for 23 min" (from 5 min on) or "Stopped".
  String? _motion(AppLocalizations l10n, LiveLocation? loc, DateTime now) {
    if (loc?.motion == null) return null;
    final idle = idleFor(
      motion: loc!.motion,
      stillSince: loc.stillSince,
      fixAt: loc.fixAt,
      updatedAt: loc.updatedAt,
      now: now,
    );
    String duration(Duration d) =>
        d.inMinutes < 60 ? l10n.durationMinutes(d.inMinutes) : l10n.durationHoursMinutes(d.inHours, d.inMinutes % 60);
    return switch (loc.motion!) {
      Motion.driving => l10n.motionDriving,
      Motion.walking => l10n.motionWalking,
      Motion.still => idle != null && idle >= idleShownAfter ? l10n.motionIdleFor(duration(idle)) : l10n.motionStopped,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final byId = {for (final u in users) u.id: u};
    final now = DateTime.now();
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final companyId = ref.watch(peopleCompanyProvider);
    final activeSites = [
      for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[])
        if (s.active) s,
    ];
    final territory = ref.watch(territoryRegionsProvider);
    bool ofCompany(AppUser u) => companyId == null || u.companyId == companyId;

    // ---- The mode's people (before region / site / search) ----
    var candidates = <_Pin>[]; // everyone the filter card counts companies of
    var pins = <_Pin>[];
    Widget? groupChips;
    String? note;
    var noneText = l10n.noOneMatches;
    LiveLocation? Function(String id) locOf = (_) => null;
    Presence? Function(String id) presenceOf = (_) => null;
    String Function(String id) statusOf = (_) => '';

    if (_employees) {
      // Today's attendance, the Attendance page's people.
      final everyone = employeePeople(ref, now);
      String? at(EmployeeOnMap p) => siteNow(
        sites: activeSites,
        lat: p.loc?.lat,
        lng: p.loc?.lng,
        accuracy: p.loc?.accuracy,
        at: p.loc?.updatedAt,
        now: now,
        inside: p.result != null && p.result!.checkInAt != null && !p.result!.closed && p.result!.inside,
        events: p.record?.events ?? const [],
      );
      candidates = [
        for (final p in everyone)
          _Pin(
            user: p.user,
            loc: p.loc,
            color: employeeStatusColor(context, p),
            fill: p.live ? Colors.white : Colors.grey.shade300,
            faded: !p.live,
            line: [employeeRowLine(context, l10n, p), p.siteName].where((s) => s.isNotEmpty).join(' · '),
            trailing: p.report.problemCount > 0
                ? Tooltip(
                    message: p.report.quiet != null
                        ? quietLine(context, p.report.quiet!, p.report.lastPosition, now)
                        : l10n.phoneStatusProblems(p.report.problemCount),
                    child: Icon(Icons.phonelink_erase, color: theme.colorScheme.error, size: 20),
                  )
                : null,
            siteNow: at(p),
            // Located first, then by status.
            order: (p.loc == null ? 100 : 0) + p.filter.index,
            status: p.filter,
          ),
      ];
      pins = [for (final p in candidates) if (ofCompany(p.user)) p];
      locOf = (id) => everyone.where((p) => p.user.id == id).firstOrNull?.loc;
    } else {
      // Live positions (live / drivers / history).
      final presence = ref.watch(presenceProvider).value ?? const <String, Presence>{};
      final onlyIds = _onlyIds;
      final driversOnly = widget.mode == PeopleMapMode.drivers;
      // Department heads, logistics / factory managers, warehouse supervisors
      // (2026-11-14): only the people under them (the logistics manager also
      // every driver); KAM: their team; SM / GM: everyone.
      final teamScoped = me?.teamScopedMaps ?? true;
      final team = me == null ? const <String>{} : {for (final u in peopleUnder(me, users)) u.id};
      bool inTeam(AppUser u) => team.contains(u.id) || (u.role.isDriver && (me?.can.managesDrivers ?? false));
      final tracked = users.where((u) {
        if (!u.active || !u.role.isLocationTracked) return false;
        if (driversOnly && !u.role.isDriver) return false;
        if (onlyIds != null && !onlyIds.contains(u.id)) return false;
        if (me?.kamOnly == true) return u.id == me!.id || u.kamId == me.id;
        if (teamScoped) return inTeam(u);
        return true;
      }).toList();
      // Everyone else whose GPS is recorded for attendance (sales manager /
      // GM: all of them; department heads: their own people).
      final staffGroup = !driversOnly && ((me?.can.isAdmin ?? false) || teamScoped);
      final staffAll = !staffGroup
          ? const <AppUser>[]
          : users
              .where((u) =>
                  u.recordsGps &&
                  !u.role.isLocationTracked &&
                  (onlyIds == null || onlyIds.contains(u.id)) &&
                  (!teamScoped || team.contains(u.id)))
              .toList();
      final everyone = tracked.where(ofCompany).toList();
      final staff = staffAll.where(ofCompany).toList();
      final driverCount = everyone.where((u) => u.role.isDriver).length;
      final salesCount = everyone.length - driverCount;
      // Team-scoped: only the groups they have people in.
      final groupOptions = [
        if (!teamScoped || salesCount > 0) _Group.sales,
        if (!teamScoped || driverCount > 0) _Group.drivers,
        if (staffGroup && (!teamScoped || staff.isNotEmpty)) _Group.staff,
      ];
      final showGroups = !driversOnly &&
          (teamScoped ? groupOptions.length > 1 : (driverCount > 0 || (me?.can.isAdmin ?? false)));
      if (onlyIds != null && !_groupPicked && users.isNotEmpty) {
        _groupPicked = true;
        if (everyone.length == driverCount && driverCount > 0) {
          _group = _Group.drivers;
        } else if (everyone.isEmpty && staff.isNotEmpty) {
          _group = _Group.staff;
        }
      }
      final group = driversOnly
          ? _Group.drivers
          : teamScoped
              ? (groupOptions.contains(_group) ? _group : groupOptions.firstOrNull ?? _Group.sales)
              : (showGroups ? _group : _Group.sales);
      final recorded = group == _Group.staff;
      final inGroup = recorded ? staffAll : tracked.where((u) => u.role.isDriver == (group == _Group.drivers)).toList();
      final staffKey = (DateFormat('yyyy-MM-dd').format(now), (staff.map((u) => u.id).toList()..sort()).join(','));
      final locations = recorded
          ? ref.watch(recordedLocationsProvider(staffKey)).value ?? const <String, LiveLocation>{}
          : ref.watch(liveLocationsProvider).value ?? const <String, LiveLocation>{};
      LiveState stateOf(String id) =>
          recorded ? recordedState(locations[id], now) : liveState(locations[id], presence[id], now);
      // Why someone who should share sends nothing (2026-11-04).
      final devices = ref.watch(deviceStatusesProvider).value ?? const <String, DeviceStatus>{};
      final hours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
      final schedules = ref.watch(trackingSchedulesProvider).value ?? const <String, TrackingSchedule>{};
      String? reasonOf(String id) {
        final u = byId[id];
        if (u == null) return null;
        final shares = (schedules[id] ?? const TrackingSchedule.standard()).isOn(
          now,
          hours,
          driver: u.role.isDriver,
          recordOnly: u.recordsGps,
          officeHours: u.role.tracksOfficeHours,
          days: u.workSchedule?.days,
        );
        if (!shares) return null;
        final loc = locations[id];
        final why = quietReason(
          device: devices[id],
          presence: recorded ? null : presence[id],
          lastPosition: loc?.updatedAt,
          now: now,
        );
        return why == null ? null : quietLine(context, why, loc?.updatedAt, now);
      }

      String status(String id) {
        final loc = locations[id];
        final state = stateOf(id);
        if (state == LiveState.offline || (recorded && state != LiveState.live)) {
          final why = reasonOf(id);
          if (why != null) return why;
        }
        if (recorded) {
          if (loc == null) return l10n.noPositionRecordedToday;
          return state == LiveState.live
              ? l10n.liveUpdated(timeAgo(context, loc.updatedAt, now))
              : l10n.lastPositionRecorded(timeAgo(context, loc.updatedAt, now));
        }
        final p = presence[id];
        if (loc == null && p == null) return l10n.noLocationYet;
        return switch (state) {
          LiveState.live => [l10n.liveUpdated(timeAgo(context, loc?.updatedAt, now)), ?_motion(l10n, loc, now)].join(' · '),
          LiveState.stale => p != null && !p.gpsOn ? l10n.liveGpsOff : l10n.liveNoFix(timeAgo(context, loc?.updatedAt, now)),
          LiveState.offDuty => l10n.liveOffDuty,
          LiveState.offline => l10n.liveOffline(timeAgo(context, p?.lastSeen ?? loc?.updatedAt, now)),
        };
      }

      const order = {LiveState.live: 0, LiveState.stale: 1, LiveState.offDuty: 2, LiveState.offline: 3};
      _Pin pin(AppUser u) {
        final loc = locations[u.id];
        final color = _liveColor(stateOf(u.id));
        final manager = u.role == UserRole.salesManager;
        return _Pin(
          user: u,
          loc: loc,
          color: color,
          // Sales manager: blue with white initials (user 2026-11-07).
          fill: manager ? managerPinColor : Colors.white,
          textColor: manager ? Colors.white : color,
          mocked: loc?.mocked ?? false,
          line: recorded ? '${u.role.label(l10n)} · ${status(u.id)}' : status(u.id),
          siteNow: siteNow(
            sites: activeSites,
            lat: loc?.lat,
            lng: loc?.lng,
            accuracy: loc?.accuracy,
            at: loc?.updatedAt,
            now: now,
          ),
          order: order[stateOf(u.id)]!,
          trailing: _history ? const Icon(Icons.route) : null,
        );
      }

      candidates = [for (final u in [...tracked, ...staffAll]) pin(u)];
      pins = [for (final u in inGroup) if (ofCompany(u)) pin(u)];
      locOf = (id) => locations[id];
      presenceOf = (id) => recorded ? null : presence[id];
      statusOf = status;
      if (recorded) note = l10n.productionLogisticsNote;
      noneText = switch (group) {
        _Group.sales => l10n.noTrackedStaff,
        _Group.drivers => l10n.noDriversYet,
        _Group.staff => l10n.noOtherEmployees,
      };
      if (showGroups || onlyIds != null) {
        groupChips = Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showGroups)
              for (final (g, icon, label) in [
                (_Group.sales, Icons.storefront_outlined, l10n.salesTeamCount(everyone.length - driverCount)),
                (_Group.drivers, Icons.local_shipping_outlined, l10n.driversCount(driverCount)),
                (_Group.staff, Icons.badge_outlined, l10n.otherEmployeesCount(staff.length)),
              ])
                if (groupOptions.contains(g))
                ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: group == g,
                  showCheckmark: false,
                  // A department of the old group means nothing here (user 2026-11-11).
                  onSelected: (_) => _filtered(() {
                    _group = g;
                    _department = null;
                  }),
                ),
            if (onlyIds != null)
              InputChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.phone_android, size: 16),
                label: Text(l10n.fromPhoneStatus(onlyIds.length)),
                onDeleted: () => _filtered(() => _onlyIds = null),
              ),
          ],
        );
      }
    }

    // ---- Shared filters: region, company (above), site, search ----
    final region = _region;
    bool inRegion(SaudiRegion? r, _Pin p) => personInRegion(
      r,
      lat: p.loc?.lat,
      lng: p.loc?.lng,
      siteIds: p.user.workSiteIds,
      sites: activeSites,
      territory: territory[p.user.id],
    );
    final sites = sitesOfCompany([
      for (final s in activeSites)
        if (region == null || region.contains(s.lat, s.lng)) s,
    ], companyId);
    final site = sites.where((s) => s.id == _siteId).firstOrNull;
    final q = foldSearch(_query);
    final scoped = [
      for (final p in pins)
        if (inRegion(region, p) &&
            (site == null || showsUnderSite(site.id, now: p.siteNow, assigned: p.user.workSiteIds)) &&
            searchHas(p.user.name, q))
          p,
    ];

    // ---- The mode's own chips over the scoped people ----
    Widget? modeChips;
    var shown = scoped;
    if (_history) {
      final departments = ref.watch(departmentsProvider).value ?? defaultDepartments;
      final counts = <String, int>{};
      for (final p in scoped) {
        counts[p.user.departmentId ?? ''] = (counts[p.user.departmentId ?? ''] ?? 0) + 1;
      }
      // A department with nobody left counts as not picked.
      final dept = counts.containsKey(_department) ? _department : null;
      shown = [for (final p in scoped) if (dept == null || (p.user.departmentId ?? '') == dept) p];
      final options = [
        for (final d in departments)
          if ((counts[d.id] ?? 0) > 0) (d.id, d.label(lang)),
        if ((counts[''] ?? 0) > 0) ('', l10n.noDepartment),
      ];
      if (options.length > 1) {
        modeChips = Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              label: Text('${l10n.all} (${scoped.length})'),
              selected: dept == null,
              onSelected: (_) => _filtered(() => _department = null),
            ),
            for (final (id, label) in options)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                avatar: const Icon(Icons.groups_outlined, size: 16),
                label: Text('$label (${counts[id]})'),
                selected: dept == id,
                onSelected: (on) => _filtered(() => _department = on ? id : null),
              ),
          ],
        );
      }
      note = [?note, l10n.routeHistoryPickPerson].join('\n');
    } else if (_employees) {
      final counts = {for (final f in EmployeeFilter.values) f: scoped.where((p) => p.status == f).length};
      final picked = {for (final f in _statuses) if (counts[f]! > 0) f};
      shown = [for (final p in scoped) if (picked.isEmpty || picked.contains(p.status)) p];
      modeChips = Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (f, color, label) in [
            (EmployeeFilter.onSite, Colors.green.shade700, l10n.onSite),
            (EmployeeFilter.away, Colors.orange.shade800, l10n.leftTheSite),
            (EmployeeFilter.notIn, Colors.grey.shade600, l10n.notCheckedIn),
            (EmployeeFilter.checkedOut, Colors.indigo, l10n.checkedOutTitle),
            (EmployeeFilter.noAttendance, Colors.blueGrey, l10n.notOnAttendance),
          ])
            if (counts[f]! > 0)
              FilterChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.circle, size: 12, color: color),
                label: Text('$label (${counts[f]})'),
                selected: picked.contains(f),
                showCheckmark: false,
                onSelected: (on) => _filtered(() => on ? _statuses.add(f) : _statuses.remove(f)),
              ),
        ],
      );
      note = [l10n.employeesCount(shown.length), l10n.employeesMapNote].join(' · ');
    }
    shown = [...shown]..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.user.name.compareTo(b.user.name));

    // ---- The selected person ----
    final selected = _selected == null ? null : byId[_selected];
    final selectedPin = selected == null
        ? null
        : candidates.where((p) => p.user.id == selected.id).firstOrNull ??
            pins.where((p) => p.user.id == selected.id).firstOrNull;
    final route = _history && selected != null
        ? _route.build(
            context,
            ref,
            person: selected,
            day: _day,
            onDay: (d) => setState(() => _day = d),
            map: _map,
            icons: _icons,
          )
        : null;

    // ---- Map ----
    final located = [for (final p in shown) if (p.loc != null) p];
    final points = route?.focus ?? [for (final p in located) LatLng(p.loc!.lat, p.loc!.lng)];
    final fitKey = route != null
        ? 'route|${route.fitKey}'
        : 'list|${widget.mode}|$_group|$region|$companyId|${site?.id}|$_query|$_department|$_statuses|${_onlyIds?.length}|${points.isNotEmpty}';
    // Not while one person's live details are open (the map zoomed to them).
    if (_map != null && _fitKey != fitKey && (route != null || _selected == null)) {
      _fitKey = fitKey;
      final map = _map!;
      final size = MediaQuery.sizeOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route == null && site != null) {
          map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(site.lat, site.lng), 16));
        } else if (points.isNotEmpty) {
          fitPoints(map, points, padding: 48);
        } else if (route == null && region != null) {
          region.zoomTo(map, size);
        }
      });
    }

    final googleMap = GoogleMap(
      initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 6),
      mapType: ref.watch(mapTypeProvider),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: (c) => setState(() => _map = c),
      onCameraMove: _icons.zoomChanged,
      polylines: route?.polylines ?? const {},
      circles: route != null
          ? const {}
          : {
              for (final s in sites)
                Circle(
                  circleId: CircleId('site_${s.id}'),
                  center: LatLng(s.lat, s.lng),
                  radius: s.radius,
                  strokeWidth: s.id == _siteId ? 3 : 1,
                  strokeColor: Colors.blue.shade700,
                  fillColor: Colors.blue.withValues(alpha: s.id == _siteId ? 0.15 : 0.06),
                ),
              if (!_employees)
                for (final p in located)
                  if (p.loc!.accuracy case final accuracy?)
                    Circle(
                      circleId: CircleId(p.user.id),
                      center: LatLng(p.loc!.lat, p.loc!.lng),
                      radius: accuracy,
                      strokeWidth: 0,
                      fillColor: p.color.withValues(alpha: 0.12),
                    ),
            },
      markers: route != null
          ? {...siteMarkers(context, _icons, sites), ...route.markers}
          : {
              // Work sites as icons by kind (2026-11-12).
              ...siteMarkers(context, _icons, sites, selectedId: _siteId),
              for (final p in located)
                Marker(
                  markerId: MarkerId(p.user.id),
                  position: LatLng(p.loc!.lat, p.loc!.lng),
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: p.user.id == _selected ? 3 : 2,
                  icon: _icons.circle(
                    context: context,
                    fill: p.fill,
                    text: initialsOf(p.user.name),
                    textColor: p.textColor ?? p.color,
                    ring: p.user.id == _selected
                        ? Colors.black
                        : p.mocked
                            ? theme.colorScheme.error
                            : p.color,
                    ringWidth: 4,
                    size: p.user.id == _selected ? 46 : 40,
                  ),
                  onTap: () => _select(p, wide),
                ),
            },
    );

    // ---- Filter card (regions, companies, sites) ----
    final allCompanies = ref.watch(companiesProvider).value ?? const <Company>[];
    final regionCompanyIds = {
      for (final p in candidates)
        if (inRegion(region, p)) p.user.companyId,
    };
    final filterCard = PositionedDirectional(
      top: 8,
      start: 8,
      end: 8,
      child: PeopleFilterCard(
        region: region,
        onRegion: (r) => _filtered(() {
          // A site outside the new region would leave the map empty.
          final picked = activeSites.where((s) => s.id == _siteId).firstOrNull;
          if (r != null && picked != null && !r.contains(picked.lat, picked.lng)) _siteId = null;
          _region = r;
        }),
        hasCompanies: allCompanies.length > 1,
        companies: [
          for (final c in allCompanies)
            if (region == null || regionCompanyIds.contains(c.id) || c.id == companyId) c,
        ],
        companyId: companyId,
        onCompany: (id) {
          // A site of another company is dropped (the company narrows the sites).
          final picked = activeSites.where((s) => s.id == _siteId).firstOrNull;
          ref.read(peopleCompanyProvider.notifier).set(id);
          _filtered(() {
            if (id != null && picked != null && picked.companyId != id) _siteId = null;
          });
        },
        sites: sites,
        siteId: _siteId,
        onSite: (s) => _filtered(() => _siteId = s?.id),
      ),
    );
    Widget mapButtons(double bottom) => PositionedDirectional(
      end: 12,
      bottom: bottom,
      child: PointerInterceptor(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MapTypeButton(),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'peopleFit',
              tooltip: l10n.showEveryone,
              onPressed: points.isEmpty || _map == null ? null : () => fitPoints(_map!, points, padding: 48),
              child: const Icon(Icons.zoom_out_map),
            ),
          ],
        ),
      ),
    );

    // ---- Pane / sheet content ----
    List<Widget> listItems() => [
      if (groupChips != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: groupChips),
      if (modeChips != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: modeChips),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.searchByName,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      if (note != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(note, style: theme.textTheme.bodySmall),
        ),
      if (shown.isEmpty)
        ListTile(
          title: Text(_query.isNotEmpty || region != null || site != null || pins.isNotEmpty ? l10n.noOneMatches : noneText),
        ),
      for (final p in shown)
        ListTile(
          selected: p.user.id == _selected,
          leading: _Avatar(name: p.user.name, color: p.color, faded: p.faded, mocked: p.mocked),
          title: Text(p.user.name),
          subtitle: Text(p.line, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: p.trailing,
          onTap: () => _select(p, wide),
        ),
    ];

    List<Widget> detailItems(AppUser u) {
      final company = ref.watch(companyNamesProvider)[u.companyId];
      return [
        // ✕ before the name, back to the list (user 2026-11-11).
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.close,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selected = null;
                  _fitKey = null; // back to everyone shown
                }),
              ),
              const SizedBox(width: 4),
              _Avatar(
                name: u.name,
                color: selectedPin?.color ?? theme.colorScheme.outline,
                faded: selectedPin?.faded ?? true,
                mocked: selectedPin?.mocked ?? false,
              ),
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
            ],
          ),
        ),
        if (route != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: route.details)
        else if (_employees)
          EmployeeDetails(key: ValueKey(u.id), uid: u.id)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LiveDetails(user: u, loc: locOf(u.id), presence: presenceOf(u.id), status: statusOf(u.id), color: selectedPin?.color),
          ),
      ];
    }

    final paneItems = selected != null ? detailItems(selected) : listItems();
    final title = switch (widget.mode) {
      PeopleMapMode.live => l10n.liveTracking,
      PeopleMapMode.drivers => l10n.driversPage,
      PeopleMapMode.history => l10n.routeHistory,
      PeopleMapMode.employees => l10n.employeesMap,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, c) {
          if (wide) {
            return Row(
              children: [
                Expanded(child: Stack(children: [googleMap, filterCard, mapButtons(16)])),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: c.maxWidth >= 1300 ? 420 : 360,
                  child: ListView(
                    padding: EdgeInsets.only(top: selected != null ? 4 : 12, bottom: 24),
                    children: paneItems,
                  ),
                ),
              ],
            );
          }
          // Phones: the same content in a sheet over the bottom of the map.
          final minSize = (84 / c.maxHeight).clamp(0.08, 0.4);
          final initial = _employees ? minSize : 0.28.clamp(minSize, 0.7);
          final sheetTop = c.maxHeight * initial;
          return Stack(
            children: [
              Padding(padding: EdgeInsets.only(bottom: sheetTop - 16), child: googleMap),
              filterCard,
              mapButtons(sheetTop + 8),
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: initial,
                minChildSize: minSize,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: [if (initial > minSize) initial, if (0.5 > initial) 0.5],
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
                        ...paneItems,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Live tracking's details: state, accuracy, warnings, Call / Open in Maps /
/// Route history. [presence] null: recorded GPS (no presence).
class _LiveDetails extends StatelessWidget {
  const _LiveDetails({required this.user, required this.loc, required this.presence, required this.status, this.color});

  final AppUser user;
  final LiveLocation? loc;
  final Presence? presence;
  final String status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final loc = this.loc;
    final p = presence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(status)),
          ],
        ),
        if (loc?.accuracy != null) Text(l10n.locationAccuracy(loc!.accuracy!.round())),
        if (loc?.mocked ?? false) Text(l10n.mockedLocationWarning, style: TextStyle(color: error)),
        if (p != null && p.permission.isNotEmpty && p.permission != 'always')
          Text(l10n.liveNotAlways, style: TextStyle(color: error)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (user.phone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${user.phone}')),
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
            // Today's route of this person (also for drivers).
            FilledButton.tonalIcon(
              onPressed: () => context.push('/history?uid=${user.id}'),
              icon: const Icon(Icons.route),
              label: Text(l10n.routeHistoryToday),
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.faded, required this.mocked});

  final String name;
  final Color color;

  /// An older position (or none): grey fill, as on the map.
  final bool faded;
  final bool mocked;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: faded ? Colors.grey.shade300 : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: mocked ? Theme.of(context).colorScheme.error : color, width: 4),
      boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
    ),
    alignment: Alignment.center,
    child: Text(initialsOf(name), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
  );
}
