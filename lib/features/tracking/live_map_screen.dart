import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/person_style.dart';
import '../users/users_repository.dart';
import 'live_data.dart';

/// Live positions of field staff. KAMs see their team (and themselves);
/// sales manager and GM see everyone.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

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

  String _ago(AppLocalizations l10n, DateTime? t, DateTime now) {
    if (t == null) return l10n.never;
    final m = now.difference(t).inMinutes;
    if (m < 1) return l10n.justNow;
    if (m < 60) return l10n.minutesAgo(m);
    if (m < 24 * 60) return l10n.hoursAgo(m ~/ 60);
    return DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(t);
  }

  String _status(AppLocalizations l10n, LiveState s, LiveLocation? loc, Presence? p, DateTime now) => switch (s) {
    LiveState.live => l10n.liveUpdated(_ago(l10n, loc?.updatedAt, now)),
    LiveState.stale => p != null && !p.gpsOn ? l10n.liveGpsOff : l10n.liveNoFix(_ago(l10n, loc?.updatedAt, now)),
    LiveState.offDuty => l10n.liveOffDuty,
    LiveState.offline => l10n.liveOffline(_ago(l10n, p?.lastSeen ?? loc?.updatedAt, now)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final locations = ref.watch(liveLocationsProvider).value ?? const {};
    final presence = ref.watch(presenceProvider).value ?? const {};
    final now = DateTime.now();

    final people = users.where((u) {
      if (!u.active || !u.role.isTracked) return false;
      if (me?.role == UserRole.kam) return u.id == me!.id || u.kamId == me.id;
      return true;
    }).toList();
    final order = {LiveState.live: 0, LiveState.stale: 1, LiveState.offDuty: 2, LiveState.offline: 3};
    people.sort((a, b) {
      final sa = liveState(locations[a.id], presence[a.id], now);
      final sb = liveState(locations[b.id], presence[b.id], now);
      return order[sa]!.compareTo(order[sb]!) != 0 ? order[sa]!.compareTo(order[sb]!) : a.name.compareTo(b.name);
    });
    final located = [
      for (final u in people)
        if (locations[u.id] != null) u,
    ];
    final points = [for (final u in located) LatLng(locations[u.id]!.lat, locations[u.id]!.lng)];

    if (_map != null && !_fitted && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll(points));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveTracking)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
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
                    fillColor: _color(liveState(locations[u.id], presence[u.id], now)).withValues(alpha: 0.12),
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
                    textColor: _color(liveState(locations[u.id], presence[u.id], now)),
                    ring: locations[u.id]!.mocked
                        ? Theme.of(context).colorScheme.error
                        : _color(liveState(locations[u.id], presence[u.id], now)),
                    ringWidth: 4,
                    size: 40,
                  ),
                  onTap: () => _showPerson(u, locations[u.id], presence[u.id]),
                ),
            },
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
                    if (people.isEmpty) ListTile(title: Text(l10n.noTrackedStaff)),
                    for (final u in people)
                      Builder(
                        builder: (context) {
                          final loc = locations[u.id];
                          final p = presence[u.id];
                          final s = liveState(loc, p, now);
                          return ListTile(
                            leading: _Avatar(name: u.name, color: _color(s), mocked: loc?.mocked ?? false),
                            title: Text(u.name),
                            subtitle: Text(
                              loc == null && p == null ? l10n.noLocationYet : _status(l10n, s, loc, p, now),
                            ),
                            trailing: loc == null ? null : const Icon(Icons.center_focus_strong),
                            onTap: loc == null
                                ? null
                                : () => _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 16)),
                            onLongPress: () => _showPerson(u, loc, p),
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

  void _showPerson(AppUser u, LiveLocation? loc, Presence? p) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final s = liveState(loc, p, now);
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
                  Expanded(child: Text(_status(l10n, s, loc, p, now))),
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
            ],
          ),
        ),
      ),
    );
  }
}

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
