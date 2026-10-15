import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';

/// Shows where [client] is on a small map, with directions in Google Maps.
/// Only for clients with a location.
Future<void> showClientLocation(BuildContext context, Client client) {
  final l10n = AppLocalizations.of(context);
  final position = LatLng(client.lat!, client.lng!);
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(client.name),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 480,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: position, zoom: 16),
            markers: {Marker(markerId: MarkerId(client.id), position: position)},
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.close)),
        FilledButton.icon(
          icon: const Icon(Icons.directions),
          label: Text(l10n.directions),
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${client.lat},${client.lng}'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    ),
  );
}

/// Green pin that opens [showClientLocation], or a grey "no location" mark.
class ClientLocationButton extends StatelessWidget {
  const ClientLocationButton({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return client.hasLocation
        ? IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.location_on, color: Colors.green.shade700),
            tooltip: l10n.showLocation,
            onPressed: () => showClientLocation(context, client),
          )
        : Tooltip(
            message: l10n.noLocation,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.location_off, color: Colors.grey),
            ),
          );
  }
}
