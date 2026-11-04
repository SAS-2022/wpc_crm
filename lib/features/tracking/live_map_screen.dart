import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/city_areas.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/person_style.dart';
import '../users/company_filter.dart';
import '../users/users_repository.dart';
import '../devices/device_status.dart';
import '../devices/quiet_reason_text.dart';
import 'live_data.dart';
import 'tracking_schedule.dart';
import 'work_hours.dart';
import 'motion.dart';

/// "Just now", "5 min ago", "2 h ago", else the date and time.
String timeAgo(BuildContext context, DateTime? t, DateTime now) {
  final l10n = AppLocalizations.of(context);
  if (t == null) return l10n.never;
  final m = now.difference(t).inMinutes;
  if (m < 1) return l10n.justNow;
  if (m < 60) return l10n.minutesAgo(m);
  if (m < 24 * 60) return l10n.hoursAgo(m ~/ 60);
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(t);
}

/// Live positions of field staff. KAMs see their team (and themselves);
/// sales manager and GM see everyone.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key, this.driversOnly = false, this.onlyIds});

  /// The Drivers page: drivers only, no Sales team / Drivers switch.
  final bool driversOnly;

  /// Opened from Phone status with a search or "Problems only" on: just the
  /// people that page showed (`/live?ids=a,b`; user 2026-11-02).
  final Set<String>? onlyIds;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });
  Timer? _tick;
  bool _fitted = false;

  /// Drivers are listed apart from the sales team (user request 2026-10-20),
  /// the other employees too (2026-11-01).
  _Group _group = _Group.sales;

  /// Region buttons (user request 2026-11-04, were cities) and company filter.
  SaudiRegion? _city;

  /// [LiveMapScreen.onlyIds] until the chip is cleared; the group shown
  /// first is the first one with any of them.
  late Set<String>? _onlyIds = widget.onlyIds;
  bool _groupPicked = false;

  @override
  void initState() {
    super.initState();
    // Refresh "x min ago" and live/stale states.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Color _color(LiveState s) => switch (s) {
    LiveState.live => Colors.green.shade600,
    LiveState.stale => Colors.orange.shade700,
    LiveState.offDuty => Colors.blueGrey,
    LiveState.offline => Colors.grey,
  };

  String _ago(AppLocalizations l10n, DateTime? t, DateTime now) => timeAgo(context, t, now);

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
    return switch (loc.motion!) {
      Motion.driving => l10n.motionDriving,
      Motion.walking => l10n.motionWalking,
      Motion.still => idle != null && idle >= idleShownAfter ? l10n.motionIdleFor(_duration(l10n, idle)) : l10n.motionStopped,
    };
  }

  String _duration(AppLocalizations l10n, Duration d) =>
      d.inMinutes < 60 ? l10n.durationMinutes(d.inMinutes) : l10n.durationHoursMinutes(d.inHours, d.inMinutes % 60);

  String _status(AppLocalizations l10n, LiveState s, LiveLocation? loc, Presence? p, DateTime now) => switch (s) {
    LiveState.live => [l10n.liveUpdated(_ago(l10n, loc?.updatedAt, now)), ?_motion(l10n, loc, now)].join(' · '),
    LiveState.stale => p != null && !p.gpsOn ? l10n.liveGpsOff : l10n.liveNoFix(_ago(l10n, loc?.updatedAt, now)),
    LiveState.offDuty => l10n.liveOffDuty,
    LiveState.offline => l10n.liveOffline(_ago(l10n, p?.lastSeen ?? loc?.updatedAt, now)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final presence = ref.watch(presenceProvider).value ?? const {};
    final now = DateTime.now();
    final companyId = ref.watch(peopleCompanyProvider);
    final onlyIds = _onlyIds;

    // The logistics manager sees drivers only.
    final driversOnly = widget.driversOnly || !(me?.role.isSupervisor ?? false);
    final everyone = users.where((u) {
      if (!u.active || !u.role.isLocationTracked) return false;
      if (driversOnly && !u.role.isDriver) return false;
      if (companyId != null && u.companyId != companyId) return false;
      if (onlyIds != null && !onlyIds.contains(u.id)) return false;
      if (me?.role == UserRole.kam) return u.id == me!.id || u.kamId == me.id;
      // Warehouse supervisor: their own drivers.
      if (me?.role == UserRole.warehouseSupervisor) return u.supervisorId == me!.id;
      return true;
    }).toList();
    final driverCount = everyone.where((u) => u.role.isDriver).length;
    // Every other employee whose GPS is recorded for attendance (sales
    // manager / GM; 08:00–18:00 on work days, [AppUser.recordsGps]): production
    // and logistics (2026-11-01), office staff too since the same day.
    final staff = driversOnly || !(me?.role.isAdmin ?? false)
        ? const <AppUser>[]
        : users
            .where((u) =>
                u.recordsGps &&
                (companyId == null || u.companyId == companyId) &&
                (onlyIds == null || onlyIds.contains(u.id)))
            .toList();
    // Sales manager / GM always see the switch (drivers may not share yet).
    final showGroups = !driversOnly && (driverCount > 0 || (me?.role.isAdmin ?? false));
    if (onlyIds != null && !_groupPicked && users.isNotEmpty) {
      _groupPicked = true;
      if (everyone.length == driverCount && driverCount > 0) {
        _group = _Group.drivers;
      } else if (everyone.isEmpty && staff.isNotEmpty) {
        _group = _Group.staff;
      }
    }
    final group = driversOnly ? _Group.drivers : (showGroups ? _group : _Group.sales);
    final recorded = group == _Group.staff;
    final inGroup = recorded ? staff : everyone.where((u) => u.role.isDriver == (group == _Group.drivers)).toList();
    final staffKey = (DateFormat('yyyy-MM-dd').format(now), (staff.map((u) => u.id).toList()..sort()).join(','));
    final locations = recorded
        ? ref.watch(recordedLocationsProvider(staffKey)).value ?? const <String, LiveLocation>{}
        : ref.watch(liveLocationsProvider).value ?? const <String, LiveLocation>{};
    LiveState stateOf(String id) =>
        recorded ? recordedState(locations[id], now) : liveState(locations[id], presence[id], now);
    // Why someone who should share sends nothing (2026-11-04, user:
    // "Offline" didn't say what was really happening).
    final devices = ref.watch(deviceStatusesProvider).value ?? const <String, DeviceStatus>{};
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final schedules = ref.watch(trackingSchedulesProvider).value ?? const <String, TrackingSchedule>{};
    final byId = {for (final u in users) u.id: u};
    String? reasonOf(String id) {
      final u = byId[id];
      if (u == null) return null;
      final shares = (schedules[id] ?? const TrackingSchedule.standard()).isOn(
        now,
        company,
        driver: u.role.isDriver,
        recordOnly: u.recordsGps,
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

    String statusOf(String id) {
      final loc = locations[id];
      final state = stateOf(id);
      if (state == LiveState.offline || (recorded && state != LiveState.live)) {
        final why = reasonOf(id);
        if (why != null) return why;
      }
      if (recorded) {
        if (loc == null) return l10n.noPositionRecordedToday;
        return state == LiveState.live
            ? l10n.liveUpdated(_ago(l10n, loc.updatedAt, now))
            : l10n.lastPositionRecorded(_ago(l10n, loc.updatedAt, now));
      }
      final p = presence[id];
      return loc == null && p == null ? l10n.noLocationYet : _status(l10n, state, loc, p, now);
    }

    // A city picked: only the people whose position is inside it.
    final city = _city;
    final people = city == null
        ? inGroup
        : [
            for (final u in inGroup)
              if (locations[u.id] case final l? when city.contains(l.lat, l.lng)) u,
          ];
    final order = {LiveState.live: 0, LiveState.stale: 1, LiveState.offDuty: 2, LiveState.offline: 3};
    people.sort((a, b) {
      final sa = stateOf(a.id);
      final sb = stateOf(b.id);
      return order[sa]!.compareTo(order[sb]!) != 0 ? order[sa]!.compareTo(order[sb]!) : a.name.compareTo(b.name);
    });
    final located = [
      for (final u in people)
        if (locations[u.id] != null) u,
    ];
    final points = [for (final u in located) LatLng(locations[u.id]!.lat, locations[u.id]!.lng)];

    if (_map != null && !_fitted && points.isNotEmpty && city == null) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll(points));
    }

    return Scaffold(
      appBar: AppBar(title: Text(driversOnly ? l10n.driversPage : l10n.liveTracking)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
            mapType: ref.watch(mapTypeProvider),
            // The people sheet covers the bottom of the map.
            padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * 0.28),
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) => setState(() => _map = controller),
            circles: {
              for (final u in located)
                if (locations[u.id]!.accuracy case final accuracy?)
                  Circle(
                    circleId: CircleId(u.id),
                    center: LatLng(locations[u.id]!.lat, locations[u.id]!.lng),
                    radius: accuracy,
                    strokeWidth: 0,
                    fillColor: _color(stateOf(u.id)).withValues(alpha: 0.12),
                  ),
            },
            markers: {
              for (final u in located)
                Marker(
                  markerId: MarkerId(u.id),
                  position: LatLng(locations[u.id]!.lat, locations[u.id]!.lng),
                  anchor: const Offset(0.5, 0.5),
                  icon: _icons.circle(
                    context: context,
                    fill: Colors.white,
                    text: initialsOf(u.name),
                    textColor: _color(stateOf(u.id)),
                    ring: locations[u.id]!.mocked
                        ? Theme.of(context).colorScheme.error
                        : _color(stateOf(u.id)),
                    ringWidth: 4,
                    size: 40,
                  ),
                  onTap: () => _showPerson(u, locations[u.id], recorded ? null : presence[u.id], statusOf(u.id)),
                ),
            },
          ),
          const PositionedDirectional(top: 8, end: 8, child: MapTypeButton()),
          PositionedDirectional(
            top: 8,
            start: 8,
            end: 64,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: RegionChips(
                selected: city,
                onSelected: (c) => setState(() {
                  _city = c;
                  if (c != null) {
                    c.zoomTo(_map, MediaQuery.sizeOf(context), [
                      for (final u in inGroup)
                        if (locations[u.id] case final l? when c.contains(l.lat, l.lng)) LatLng(l.lat, l.lng),
                    ]);
                  } else {
                    _fitted = false; // back to everyone
                  }
                }),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.12,
            maxChildSize: 0.7,
            builder: (context, scroll) => PointerInterceptor(
              child: Material(
                elevation: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: ListView(
                  controller: scroll,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        // Chips wrap on narrow phones (three segments didn't fit).
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (showGroups)
                            for (final (g, icon, label) in [
                              (_Group.sales, Icons.storefront_outlined, l10n.salesTeamCount(everyone.length - driverCount)),
                              (_Group.drivers, Icons.local_shipping_outlined, l10n.driversCount(driverCount)),
                              if (me?.role.isAdmin ?? false)
                                (_Group.staff, Icons.badge_outlined, l10n.otherEmployeesCount(staff.length)),
                            ])
                              ChoiceChip(
                                avatar: Icon(icon, size: 18),
                                label: Text(label),
                                selected: group == g,
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  _group = g;
                                  _fitted = false; // fit the map to the group shown
                                }),
                              ),
                            CompanyFilterButton(
                              value: companyId,
                              onChanged: (id) {
                                ref.read(peopleCompanyProvider.notifier).set(id);
                                setState(() => _fitted = false);
                              },
                            ),
                            if (onlyIds != null)
                              InputChip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.phone_android, size: 16),
                                label: Text(l10n.fromPhoneStatus(onlyIds.length)),
                                onDeleted: () => setState(() {
                                  _onlyIds = null;
                                  _fitted = false;
                                }),
                              ),
                          ],
                        ),
                      ),
                    if (recorded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(l10n.productionLogisticsNote, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    if (people.isEmpty)
                      ListTile(
                        title: Text(switch (group) {
                          _Group.sales => l10n.noTrackedStaff,
                          _Group.drivers => l10n.noDriversYet,
                          _Group.staff => l10n.noOtherEmployees,
                        }),
                      ),
                    for (final u in people)
                      Builder(
                        builder: (context) {
                          final loc = locations[u.id];
                          final p = recorded ? null : presence[u.id];
                          return ListTile(
                            leading: _Avatar(name: u.name, color: _color(stateOf(u.id)), mocked: loc?.mocked ?? false),
                            title: Text(u.name),
                            subtitle: Text(recorded ? '${u.role.label(l10n)} · ${statusOf(u.id)}' : statusOf(u.id)),
                            trailing: loc == null ? null : const Icon(Icons.center_focus_strong),
                            onTap: loc == null
                                ? null
                                : () => _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 16)),
                            onLongPress: () => _showPerson(u, loc, p, statusOf(u.id)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: points.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * 0.28),
              child: PointerInterceptor(
                child: FloatingActionButton.small(
                  heroTag: 'liveFit',
                  tooltip: l10n.showEveryone,
                  onPressed: () => _fitAll(points),
                  child: const Icon(Icons.zoom_out_map),
                ),
              ),
            ),
    );
  }

  void _fitAll(List<LatLng> points) {
    if (_map != null) fitPoints(_map!, points, padding: 48);
  }

  /// [p] null: a production / logistics person (recorded GPS, no presence).
  void _showPerson(AppUser u, LiveLocation? loc, Presence? p, String status) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final s = p == null ? recordedState(loc, now) : liveState(loc, p, now);
    final error = Theme.of(context).colorScheme.error;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.name, style: Theme.of(context).textTheme.titleLarge),
              Text(u.role.label(l10n)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: _color(s)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status)),
                ],
              ),
              if (loc?.accuracy != null) Text(l10n.locationAccuracy(loc!.accuracy!.round())),
              if (loc?.mocked ?? false) Text(l10n.mockedLocationWarning, style: TextStyle(color: error)),
              if (p != null && p.permission.isNotEmpty && p.permission != 'always')
                Text(l10n.liveNotAlways, style: TextStyle(color: error)),
              if (u.phone.isNotEmpty || loc != null) const SizedBox(height: 16),
              Row(
                children: [
                  if (u.phone.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('tel:${u.phone}')),
                        icon: const Icon(Icons.phone),
                        label: Text(l10n.callPhone),
                      ),
                    ),
                  if (u.phone.isNotEmpty && loc != null) const SizedBox(width: 12),
                  if (loc != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.directions),
                        label: Text(l10n.openInMaps),
                      ),
                    ),
                ],
              ),
              // Today's route of this person (also for drivers).
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/history?uid=${u.id}');
                },
                icon: const Icon(Icons.route),
                label: Text(l10n.routeHistoryToday),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Group { sales, drivers, staff }

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, required this.mocked});

  final String name;
  final Color color;
  final bool mocked;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: mocked ? Theme.of(context).colorScheme.error : color, width: 4),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
