import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/map_controls.dart';
import '../../l10n/app_localizations.dart';

/// Move the map under the centre pin and confirm. Pops with the chosen [LatLng].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  /// Starting point; the user's position (or Riyadh) when null.
  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _map;
  late LatLng _center = widget.initial ?? defaultMapCenter;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  /// No GPS fix: stays where the map is.
  Future<void> _goToMe() async {
    final me = await locateMe();
    if (me != null && mounted) _map?.animateCamera(CameraUpdate.newLatLngZoom(me, 17));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickOnMap)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: widget.initial == null ? 12 : 17),
            // Satellite with labels helps find a shop or workshop from above.
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onCameraMove: (position) => _center = position.target,
            onMapCreated: (controller) {
              _map = controller;
              if (widget.initial == null) _goToMe();
            },
          ),
          // Fixed pin: its tip marks the map centre.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on, size: 48, color: Colors.red),
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l10n.pickOnMapHint, textAlign: TextAlign.center),
              ),
            ),
          ),
          PositionedDirectional(
            end: 12,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'pickerMe',
              tooltip: l10n.myLocation,
              onPressed: _goToMe,
              child: const Icon(Icons.my_location),
            ),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 24,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(l10n.useThisLocation),
              onPressed: () => Navigator.pop(context, _center),
            ),
          ),
        ],
      ),
    );
  }
}
