import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/map_controls.dart';
import '../../l10n/app_localizations.dart';
import '../visits/call_chip.dart';
import 'client_sheet.dart';
import 'person_style.dart';
import 'transfer_watch.dart';
import 'visit_rules.dart';

/// Amber before two weeks without a visit.
const transferWaitingColor = Color(0xFFB07800);

/// Visited (green) / called (purple) by the new salesperson, else not yet:
/// amber, red from 14 days.
Color transferColor(TransferWatch row) {
  final first = row.firstContact;
  if (first != null) return first.isCall ? callColor : statusRecentColor;
  return row.days >= 14 ? statusOverdueColor : transferWaitingColor;
}

/// Transferred clients on a map (user request 2026-10-31): the rows the
/// Transferred clients page shows with its filters (period, waiting /
/// archived, new salesperson, moved by). Pin = the new salesperson's colour
/// and initials, ring = visited / called / not yet. Tap = client sheet.
class TransfersMap extends ConsumerStatefulWidget {
  const TransfersMap({super.key, required this.rows});

  final List<TransferWatch> rows;

  @override
  ConsumerState<TransfersMap> createState() => _TransfersMapState();
}

class _TransfersMapState extends ConsumerState<TransfersMap> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });

  /// The pins last fitted; re-fitted when a filter changes what's shown.
  String? _fitted;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _goToMe() async {
    final me = await locateMe();
    if (me == null || !mounted) return;
    _map?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  void _fit(List<LatLng> points) {
    if (_map != null && points.isNotEmpty) fitPoints(_map!, points);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final styles = ref.watch(personStylesProvider);
    // One pin per client: its latest move shown (rows of a client moved twice).
    final rows = <String, TransferWatch>{};
    for (final r in widget.rows) {
      final old = rows[r.client.id];
      if (old == null || r.transfer.at!.isAfter(old.transfer.at!)) rows[r.client.id] = r;
    }
    final located = [
      for (final r in rows.values)
        if (r.client.hasLocation) r,
    ];
    final missing = rows.length - located.length;
    LatLng at(TransferWatch r) => LatLng(r.client.lat!, r.client.lng!);
    final points = [for (final r in located) at(r)];

    final signature = (rows.keys.toList()..sort()).join(',');
    if (_map != null && _fitted != signature && points.isNotEmpty) {
      _fitted = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
          mapType: ref.watch(mapTypeProvider),
          padding: const EdgeInsets.only(top: 80),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) => setState(() => _map = controller),
          markers: {
            for (final r in located)
              () {
                final style = styles[r.transfer.toId] ?? unassignedStyle;
                return Marker(
                  markerId: MarkerId(r.client.id),
                  position: at(r),
                  anchor: const Offset(0.5, 0.5),
                  icon: _icons.circle(
                    context: context,
                    fill: style.color,
                    text: style.initials,
                    ring: transferColor(r),
                    ringWidth: 4,
                    size: 34,
                  ),
                  onTap: () => showClientSheet(context, ref, r.client),
                );
              }(),
          },
        ),
        PositionedDirectional(
          end: 12,
          bottom: 32,
          child: MapControls(map: _map, onMyLocation: _goToMe, onFitAll: points.isEmpty ? null : () => _fit(points)),
        ),
        PositionedDirectional(
          top: 8,
          start: 8,
          end: 8,
          child: PointerInterceptor(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        for (final (color, label) in [
                          (statusRecentColor, l10n.transferLegendVisited),
                          (callColor, l10n.transferLegendCalled),
                          (transferWaitingColor, l10n.transferLegendWaiting),
                          (statusOverdueColor, l10n.transferLegendLate),
                        ])
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radio_button_unchecked, size: 14, color: color),
                              const SizedBox(width: 4),
                              Text(label, style: theme.textTheme.bodySmall),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.transferPinHelp, style: theme.textTheme.bodySmall),
                    if (missing > 0) Text(l10n.transfersNoLocation(missing), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
