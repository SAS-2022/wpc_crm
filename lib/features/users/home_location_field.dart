import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/place_buttons.dart';
import '../../l10n/app_localizations.dart';

/// User form, drivers (2026-10-25): their home, where their overtime ends
/// (as well as at a work site).
class HomeLocationField extends StatelessWidget {
  const HomeLocationField({super.key, required this.value, required this.onChanged});

  final ({double lat, double lng})? value;
  final ValueChanged<({double lat, double lng})?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.home_outlined, color: v == null ? theme.disabledColor : theme.colorScheme.primary),
            title: Text(l10n.homeLocation),
            subtitle: Text([
              v == null ? l10n.homeLocationNotSet : '${v.lat.toStringAsFixed(5)}, ${v.lng.toStringAsFixed(5)}',
              l10n.homeLocationHelp,
            ].join('\n')),
            trailing: v == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), tooltip: l10n.clear, onPressed: () => onChanged(null)),
          ),
          PlaceButtons(
            point: v == null ? null : LatLng(v.lat, v.lng),
            onPicked: (p) => onChanged((lat: p.latitude, lng: p.longitude)),
          ),
        ],
      ),
    );
  }
}
