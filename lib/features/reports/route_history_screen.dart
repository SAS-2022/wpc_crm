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
import '../clients/clients_repository.dart';
import '../home/dashboard_cards.dart';
import '../home/stats.dart';
import '../home/stats_widgets.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import 'report.dart';
import 'reports_data.dart';

/// One person's day from RTDB `location_history`: the route on a map with
/// the visits made, distance and first / last location. Person and day are
/// in the URL (`/history?uid=&date=`) so a view can be bookmarked or shared.
class RouteHistoryScreen extends ConsumerStatefulWidget {
  const RouteHistoryScreen({super.key, this.userId, this.date});

  final String? userId;

  /// 'yyyy-MM-dd'; null = today.
  final String? date;

  @override
  ConsumerState<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends ConsumerState<RouteHistoryScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });

  /// Person, day and whether there was something to show at the last fit.
  String? _fitted;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _open(String uid, DateTime day) => context.go('/history?uid=$uid&date=${dayKey(day)}');

  Future<void> _pickDay(String uid, DateTime day) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) _open(uid, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final team = [if (me.role.isTracked) me, ...teamOf(me, users)];
    final person = team.where((u) => u.id == widget.userId).firstOrNull ?? team.firstOrNull;
    final day = DateTime.tryParse(widget.date ?? '') ?? today;
    final dayStr = dayKey(day);

    final points = person == null
        ? const <RoutePoint>[]
        : ref.watch(routePointsProvider((person.id, dayStr))).value ?? const <RoutePoint>[];
    final route = summarizeRoute(points);
    final clients = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.id: c};
    final hidden = ref.watch(hiddenClientIdsProvider);
    final visits = (ref.watch(rangeVisitsProvider((null, monthKey(day)))).value ?? const <Visit>[])
        .where((v) =>
            person != null &&
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

    final path = [for (final p in route.path) LatLng(p.lat, p.lng)];
    LatLng latLng(RoutePoint p) => LatLng(p.lat, p.lng);
    final runs = splitAtGaps(route.path);
    final everything = [...path, for (final v in visits) ?visitPoint(v)];
    final fitKey = '${person?.id}|$dayStr|${everything.isNotEmpty}';
    if (_map != null && _fitted != fitKey && everything.isNotEmpty) {
      _fitted = fitKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => fitPoints(_map!, everything, padding: 48));
    }

    final time = DateFormat.jm(locale);
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (team.isEmpty)
          Text(l10n.noTrackedStaff)
        else
          DropdownButton<String>(
            value: person!.id,
            hint: Text(l10n.choosePerson),
            underline: const SizedBox.shrink(),
            items: [for (final u in team) DropdownMenuItem(value: u.id, child: Text(u.name))],
            onChanged: (id) => id == null ? null : _open(id, day),
          ),
        if (person != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: l10n.previousDay,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _open(person.id, DateTime(day.year, day.month, day.day - 1)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(day == today ? l10n.today : DateFormat.yMMMEd(locale).format(day)),
              onPressed: () => _pickDay(person.id, day),
            ),
            IconButton(
              tooltip: l10n.nextDay,
              icon: const Icon(Icons.chevron_right),
              onPressed: day.isBefore(today) ? () => _open(person.id, DateTime(day.year, day.month, day.day + 1)) : null,
            ),
          ]),
      ],
    );

    final summary = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: route.path.isEmpty
          ? [Text(l10n.noRouteData, style: theme.textTheme.bodyMedium)]
          : [
              _Fact(icon: Icons.route, label: l10n.distance, value: formatDistance(route.distanceMeters)),
              _Fact(icon: Icons.play_arrow, label: l10n.firstLocation, value: time.format(route.first!)),
              _Fact(icon: Icons.stop, label: l10n.lastLocation, value: time.format(route.last!)),
              _Fact(icon: Icons.event_available, label: l10n.visits, value: '${visits.length}'),
              _Fact(icon: Icons.scatter_plot, label: l10n.locationPointsCount(route.path.length), value: ''),
              if (runs.length > 1)
                _Fact(icon: Icons.signal_wifi_off, label: l10n.trackingGaps(runs.length - 1), value: ''),
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
        for (final (i, v) in visits.indexed)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 13, backgroundColor: seriesBlue, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(v.clientName),
            subtitle: Text([
              time.format(v.checkedInAt!),
              if (v.distanceMeters != null) formatDistance(v.distanceMeters!),
              if (isFlagged(v)) v.mocked ? l10n.fakeGpsFlag : l10n.farFlag,
            ].join(' · ')),
            onTap: () => context.go('/visits/${v.id}'),
          ),
      ],
    );

    final map = GoogleMap(
      initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: (controller) => setState(() => _map = controller),
      polylines: {
        // Solid where tracking was continuous.
        for (final (i, run) in runs.indexed)
          if (run.length > 1)
            Polyline(
              polylineId: PolylineId('run-$i'),
              points: [for (final p in run) latLng(p)],
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
      markers: {
        if (path.isNotEmpty) ...[
          Marker(
            markerId: const MarkerId('start'),
            position: path.first,
            anchor: const Offset(0.5, 0.5),
            icon: _icons.circle(context: context, fill: statusGood, text: 'S', size: 26),
            infoWindow: InfoWindow(title: l10n.firstLocation, snippet: time.format(route.first!)),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: path.last,
            anchor: const Offset(0.5, 0.5),
            icon: _icons.circle(context: context, fill: inkSecondary, text: 'E', size: 26),
            infoWindow: InfoWindow(title: l10n.lastLocation, snippet: time.format(route.last!)),
          ),
        ],
        for (final (i, v) in visits.indexed)
          if (visitPoint(v) case final point?)
            Marker(
              markerId: MarkerId('visit-${v.id}'),
              position: point,
              anchor: const Offset(0.5, 0.5),
              icon: _icons.circle(
                context: context,
                fill: seriesBlue,
                text: '${i + 1}',
                ring: isFlagged(v) ? theme.colorScheme.error : Colors.white,
              ),
              infoWindow: InfoWindow(title: v.clientName, snippet: time.format(v.checkedInAt!)),
            ),
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(person == null ? l10n.routeHistory : '${l10n.routeHistory} · ${person.name}')),
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [controls, const SizedBox(height: 16), summary, const SizedBox(height: 8), visitList],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: map),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [controls, const SizedBox(height: 8), summary]),
            ),
            Expanded(child: map),
            if (visits.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * 0.3),
                child: SingleChildScrollView(child: visitList),
              ),
          ],
        );
      }),
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
