import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/client_sheet.dart';
import '../clients/clients_repository.dart';
import '../home/dashboard_cards.dart';
import '../home/stats.dart';
import '../home/stats_widgets.dart';
import '../plan/plan_task.dart';
import '../tracking/tracking_log.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import 'report.dart';
import 'report_sections.dart';
import 'reports_data.dart';
import 'routing_pace.dart';
import 'timeline_widgets.dart';

/// One person's day from RTDB `location_history` for the people map's Route
/// history mode (user 2026-11-11: one page with Live tracking and the
/// Employee Map): the route lines and visit / delivery pins drawn on the
/// shared map, and the details (day, distance, visits, time split, tracking
/// log) for the right pane / phone sheet.
typedef RouteDayView = ({
  Set<Polyline> polylines,
  Set<Marker> markers,
  List<LatLng> focus,
  String fitKey,
  Widget details,
});

/// Keeps what was already asked of the Cloud Functions (snapping the route
/// to roads, the GPS timeline) so each is asked once per new data.
class RouteDay {
  /// Person, day and history count last sent to `snapRoute`.
  String? _snapAsked;
  bool _snapErrorShown = false;

  /// Person, day and history size last sent to `buildTimeline`.
  String? _timelineAsked;

  void _buildTimeline(String uid, String day, int points) {
    final key = '$uid|$day|${points ~/ 20}';
    if (_timelineAsked == key) return;
    _timelineAsked = key;
    buildTimelineNow(uid, day).ignore();
  }

  /// Has the Cloud Function snap new fixes to roads; the result arrives
  /// through [snappedRouteProvider]. Without it the route stays straight.
  void _snap(BuildContext context, String uid, String day, int count) {
    final key = '$uid|$day|$count';
    if (_snapAsked == key) return;
    _snapAsked = key;
    snapRoute(uid, day).catchError((Object e) {
      if (!context.mounted || _snapErrorShown) return;
      _snapErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).errorWithMessage(e is FirebaseFunctionsException ? e.message ?? e.code : '$e')),
      ));
    });
  }

  RouteDayView build(
    BuildContext context,
    WidgetRef ref, {
    required AppUser? person,
    required DateTime day,
    required ValueChanged<DateTime> onDay,
    required GoogleMapController? map,
    required MarkerIcons icons,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    // The benchmark (team pace) uses the whole sales team.
    final team = me == null ? const <AppUser>[] : [if (me.role.isTracked) me, ...teamOf(me, users)];
    final dayStr = dayKey(day);

    final allPoints = person == null
        ? const <RoutePoint>[]
        : ref.watch(routePointsProvider((person.id, dayStr))).value ?? const <RoutePoint>[];
    // Points from a second phone on the same account are left out.
    final points = mainTrack(allPoints);
    final ignored = allPoints.where((p) => (p.accuracy ?? 0) <= 100).length - points.length;
    final route = summarizeRoute(points);
    final snapped = person == null
        ? const SnappedRoute()
        : ref.watch(snappedRouteProvider((person.id, dayStr))).value;
    if (person != null && snapped != null && points.length > 1 && snapped.handled != allPoints.length) {
      // Today a fix comes every 30 s: ask about every 2 minutes, not per fix.
      _snap(context, person.id, dayStr, day == today ? allPoints.length ~/ 4 : allPoints.length);
    }
    final clients = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.id: c};
    final hidden = ref.watch(hiddenClientIdsProvider);
    final monthVisits = ref.watch(rangeVisitsProvider((null, monthKey(day)))).value ?? const <Visit>[];
    final visits = monthVisits
        .where((v) =>
            person != null &&
            !v.isCall && // no position to draw
            !hidden.contains(v.clientId) &&
            (v.salesExecId == person.id || v.kamId == person.id) &&
            v.checkedInAt != null &&
            dayKey(v.checkedInAt!) == dayStr)
        .toList()
      ..sort((a, b) => a.checkedInAt!.compareTo(b.checkedInAt!));

    LatLng? visitPoint(Visit v) {
      if (v.checkInLat != null && v.checkInLng != null) return LatLng(v.checkInLat!, v.checkInLng!);
      final c = clients[v.clientId];
      return c != null && c.hasLocation ? LatLng(c.lat!, c.lng!) : null;
    }

    // The day's GPS timeline, and the team benchmark of the month (median of
    // the salespeople's measured visit length, speed and road factor).
    final timeline = person == null ? null : ref.watch(dayTimelineProvider((person.id, dayStr))).value;
    if (person != null && person.role.isLocationTracked && allPoints.isNotEmpty && (timeline == null || !timeline.isFinal)) {
      _buildTimeline(person.id, dayStr, allPoints.length);
    }
    final pace = routingReport(
      people: const [],
      benchmarkPeople: team,
      visits: monthVisits,
      clients: clients,
      range: StatsRange.month(day),
      timelines: ref.watch(dayTimelinesProvider(monthKey(day))).value ?? const {},
    ).pace;
    final efficiency = paceEfficiency([
      for (final v in visits)
        if (visitPoint(v) case final p?) (at: v.checkedInAt!, place: (p.latitude, p.longitude)),
    ], pace: pace, timeline: timeline);

    // Drivers don't check in: their stops at a client's location (from the
    // timeline, matched by distance) are the deliveries.
    final isDriver = person?.role == UserRole.driver;
    final deliveries = isDriver ? [...?timeline?.clientStays.where((s) => s.lat != null)] : const <ClientStay>[];
    String deliveryName(ClientStay s) => clients[s.clientId]?.name ?? s.clientName ?? '?';

    final path = [for (final p in route.path) LatLng(p.lat, p.lng)];
    LatLng latLng(RoutePoint p) => LatLng(p.lat, p.lng);
    final runs = splitAtGaps(route.path);
    final lines = routeLines(runs, snapped?.legs ?? const []);
    // Zoom to the visited clients; the whole route (which may start at home
    // or include far-off fixes) only when there are no visits.
    final visitPoints = [for (final v in visits) ?visitPoint(v)];
    final deliveryPoints = [for (final s in deliveries) LatLng(s.lat!, s.lng!)];
    final focus = visitPoints.isNotEmpty
        ? visitPoints
        : deliveryPoints.isNotEmpty
            ? deliveryPoints
            : path;
    final fitKey = '${person?.id}|$dayStr|${visitPoints.length}|${deliveryPoints.length}|${focus.isNotEmpty}';

    final time = DateFormat.jm(locale);
    final dayBar = person == null
        ? const SizedBox.shrink()
        : Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: l10n.previousDay,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onDay(DateTime(day.year, day.month, day.day - 1)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(day == today ? l10n.today : DateFormat.yMMMEd(locale).format(day)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2025),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onDay(picked);
              },
            ),
            IconButton(
              tooltip: l10n.nextDay,
              icon: const Icon(Icons.chevron_right),
              onPressed: day.isBefore(today) ? () => onDay(DateTime(day.year, day.month, day.day + 1)) : null,
            ),
          ]);

    final summary = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: route.path.isEmpty
          ? [Text(l10n.noRouteData, style: theme.textTheme.bodyMedium)]
          : [
              _Fact(icon: Icons.route, label: l10n.distance, value: formatDistance(lines.meters)),
              _Fact(icon: Icons.play_arrow, label: l10n.firstLocation, value: time.format(route.first!)),
              _Fact(icon: Icons.stop, label: l10n.lastLocation, value: time.format(route.last!)),
              if (isDriver)
                _Fact(icon: Icons.local_shipping_outlined, label: l10n.deliveries, value: '${deliveries.length}')
              else
                _Fact(icon: Icons.event_available, label: l10n.visits, value: '${visits.length}'),
              if (efficiency != null)
                _Fact(
                  icon: Icons.speed,
                  label: l10n.efficiency,
                  value: '${(efficiency.rate * 100).round()}%',
                  color: efficiency.rate >= 0.8
                      ? statusGood
                      : efficiency.rate >= 0.6
                          ? Colors.orange.shade800
                          : theme.colorScheme.error,
                ),
              _Fact(icon: Icons.scatter_plot, label: l10n.locationPointsCount(route.path.length), value: ''),
              if (runs.length > 1)
                _Fact(icon: Icons.signal_wifi_off, label: l10n.trackingGaps(runs.length - 1), value: ''),
              if (ignored > 0)
                _Fact(
                  icon: Icons.phonelink_erase,
                  label: l10n.otherTrackIgnored(ignored),
                  value: '',
                  color: theme.colorScheme.error,
                ),
              if (route.mockedPoints > 0)
                _Fact(
                  icon: Icons.gps_off,
                  label: l10n.fakeGpsPoints(route.mockedPoints),
                  value: '',
                  color: theme.colorScheme.error,
                ),
            ],
    );

    final visitList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the work day's time went, and the stops that weren't at a client.
        if (timeline != null && timeline.minutes.values.any((n) => n > 0))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l10n.reportTimeSplit, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              TimeSplitBar(split: timeline.minutes, height: 16),
              const SizedBox(height: 6),
              TimeSplitLegend(split: timeline.minutes),
              for (final st in timeline.stops)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(timeKindIcon(st.kind), color: timeKindColor(st.kind)),
                  title: Text('${timeKindLabel(l10n, st.kind)} · ${formatSplitMinutes(l10n, st.length.inMinutes)}'),
                  subtitle: Text('${time.format(st.from)} – ${time.format(st.to)}'),
                  onTap: st.lat == null || map == null
                      ? null
                      : () => map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(st.lat!, st.lng!), 16)),
                ),
            ]),
          ),
        // Drivers: each stop at a client, arrival to departure.
        if (isDriver && route.path.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(l10n.deliveries, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text(deliveries.isEmpty ? l10n.noDeliveriesFound : l10n.deliveryStopsNote,
                style: theme.textTheme.bodySmall?.copyWith(color: inkSecondary)),
          ),
          for (final (i, s) in deliveries.indexed)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 13,
                backgroundColor: timeKindColor(TimeKind.client),
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              title: Text([deliveryName(s), if (s.locationId != null) l10n.deliveryLocationOther].join(' · ')),
              subtitle: Text([
                '${time.format(s.from)} – ${time.format(s.to)}',
                formatSplitMinutes(l10n, s.length.inMinutes),
                if (s.meters != null) l10n.deliveryFromPin(s.meters!),
              ].join(' · ')),
              onTap: map == null ? null : () => map.animateCamera(CameraUpdate.newLatLngZoom(LatLng(s.lat!, s.lng!), 17)),
            ),
        ],
        if (efficiency != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              [
                efficiency.measured
                    ? l10n.efficiencyDetail(formatLasted(l10n, efficiency.needed), formatLasted(l10n, efficiency.took))
                    : l10n.efficiencyDetailNoGps(formatLasted(l10n, efficiency.needed), formatLasted(l10n, efficiency.took)),
                efficiency.bestOrder
                    ? l10n.efficiencyBestOrder
                    : l10n.efficiencyOtherOrder(
                        formatDistance(efficiency.shortestMeters), formatDistance(efficiency.takenMeters)),
              ].join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final (i, v) in visits.indexed)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 13, backgroundColor: seriesBlue, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(v.clientName),
            subtitle: Text([
              time.format(v.checkedInAt!),
              if (v.distanceMeters != null) formatDistance(v.distanceMeters!),
              if (v.isFlagged) v.mocked ? l10n.fakeGpsFlag : l10n.farFlag,
            ].join(' · ')),
            onTap: () => context.go('/visits/${v.id}'),
          ),
      ],
    );

    return (
      polylines: <Polyline>{
        // Solid where tracking was continuous.
        for (final (i, line) in lines.lines.indexed)
          if (line.length > 1)
            Polyline(
              polylineId: PolylineId('run-$i'),
              points: [for (final (lat, lng) in line) LatLng(lat, lng)],
              color: seriesBlue,
              width: 4,
            ),
        // Thin and grey (dashed on phones; the web map can't dash) across a
        // gap: no location came, so the way taken is unknown.
        for (var i = 1; i < runs.length; i++)
          Polyline(
            polylineId: PolylineId('gap-$i'),
            points: [latLng(runs[i - 1].last), latLng(runs[i].first)],
            color: inkSecondary.withValues(alpha: 0.6),
            width: 2,
            patterns: [PatternItem.dash(12), PatternItem.gap(8)],
          ),
      },
      markers: <Marker>{
        if (path.isNotEmpty) ...[
          Marker(
            markerId: const MarkerId('start'),
            position: path.first,
            anchor: const Offset(0.5, 0.5),
            icon: icons.circle(context: context, fill: statusGood, text: 'S', size: 26),
            infoWindow: InfoWindow(title: l10n.firstLocation, snippet: time.format(route.first!)),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: path.last,
            anchor: const Offset(0.5, 0.5),
            icon: icons.circle(context: context, fill: inkSecondary, text: 'E', size: 26),
            infoWindow: InfoWindow(title: l10n.lastLocation, snippet: time.format(route.last!)),
          ),
        ],
        for (final (i, v) in visits.indexed)
          if (visitPoint(v) case final point?)
            Marker(
              markerId: MarkerId('visit-${v.id}'),
              position: point,
              anchor: const Offset(0.5, 0.5),
              icon: icons.circle(
                context: context,
                fill: seriesBlue,
                text: '${i + 1}',
                ring: v.isFlagged ? theme.colorScheme.error : Colors.white,
              ),
              // Same sheet as the clients map; a deleted client keeps the label.
              onTap: clients[v.clientId] == null ? null : () => showClientSheet(context, ref, clients[v.clientId]!, null, v),
              infoWindow: clients[v.clientId] == null
                  ? InfoWindow(title: v.clientName, snippet: time.format(v.checkedInAt!))
                  : InfoWindow.noText,
            ),
        for (final (i, s) in deliveries.indexed)
          Marker(
            markerId: MarkerId('delivery-$i'),
            position: LatLng(s.lat!, s.lng!),
            anchor: const Offset(0.5, 0.5),
            icon: icons.circle(context: context, fill: timeKindColor(TimeKind.client), text: '${i + 1}'),
            infoWindow: InfoWindow(
              title: deliveryName(s),
              snippet: '${time.format(s.from)} – ${time.format(s.to)} · ${formatSplitMinutes(l10n, s.length.inMinutes)}',
            ),
          ),
      },
      focus: focus,
      fitKey: fitKey,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: AlignmentDirectional.centerStart, child: dayBar),
          const SizedBox(height: 8),
          summary,
          const SizedBox(height: 8),
          visitList,
          if (person != null) TrackingLogList(userId: person.id, day: dayStr),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(value.isEmpty ? label : '$label: $value', style: color == null ? null : TextStyle(color: color)),
      );
}

