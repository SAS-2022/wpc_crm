import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/clients/location_picker_screen.dart';
import '../features/import/import_service.dart';
import '../l10n/app_localizations.dart';
import 'location.dart';
import 'text_input_dialog.dart';

/// "Use my location", "Paste Maps link" (short links too, or "lat, lng"
/// text) and "Pick on map" for setting a place (work sites, a driver's home;
/// 2026-10-25). Calls [onPicked] with the chosen point.
class PlaceButtons extends StatefulWidget {
  const PlaceButtons({super.key, required this.point, required this.onPicked});

  /// The current point (the map opens there).
  final LatLng? point;
  final ValueChanged<LatLng> onPicked;

  @override
  State<PlaceButtons> createState() => _PlaceButtonsState();
}

class _PlaceButtonsState extends State<PlaceButtons> {
  bool _locating = false;

  Future<void> _busy(Future<void> Function() action) async {
    setState(() => _locating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useMyLocation() => _busy(() async {
        final l10n = AppLocalizations.of(context);
        final messenger = ScaffoldMessenger.of(context);
        try {
          final result = await currentPosition();
          final p = result.position;
          if (p != null) {
            widget.onPicked(LatLng(p.latitude, p.longitude));
          } else {
            messenger.showSnackBar(SnackBar(
              content: Text(result.problem == LocationProblem.denied ? l10n.locationPermissionDenied : l10n.locationUnavailable),
            ));
          }
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.locationUnavailable)));
        }
      });

  Future<void> _pasteLink() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = await showTextInputDialog(
      context,
      title: l10n.pasteMapsLink,
      hint: l10n.pasteMapsLinkHint,
      confirmLabel: l10n.useThisLocation,
    );
    if (text == null || text.trim().isEmpty) return;
    await _busy(() async {
      final coords = await coordsFromPastedText(text);
      if (coords == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.linkUnreadable)));
      } else {
        widget.onPicked(LatLng(coords.lat, coords.lng));
      }
    });
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: widget.point)),
    );
    if (picked != null) widget.onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.my_location),
          label: Text(l10n.useMyLocation),
          onPressed: _locating ? null : _useMyLocation,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.link),
          label: Text(l10n.pasteMapsLink),
          onPressed: _locating ? null : _pasteLink,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.map_outlined),
          label: Text(l10n.pickOnMap),
          onPressed: _locating ? null : _pickOnMap,
        ),
        if (_locating) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}
