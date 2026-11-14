import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/map_controls.dart';
import '../../l10n/app_localizations.dart';
import 'work_sites.dart';

/// Work sites as icons on every map (user 2026-11-12): a rounded square per
/// site kind, under the client and people pins.
IconData siteKindIcon(SiteKind k) => switch (k) {
      SiteKind.office => Icons.business,
      SiteKind.warehouse => Icons.warehouse,
      SiteKind.showroom => Icons.storefront,
      SiteKind.factory => Icons.factory,
    };

/// Colours kept clear of the visit-status green / yellow / red and the
/// salesperson purple.
Color siteKindColor(SiteKind k) => switch (k) {
      SiteKind.office => const Color(0xFF1565C0),
      SiteKind.warehouse => const Color(0xFF6D4C41),
      SiteKind.showroom => const Color(0xFF00838F),
      SiteKind.factory => const Color(0xFF455A64),
    };

String siteKindLabel(SiteKind k, AppLocalizations l10n) => switch (k) {
      SiteKind.office => l10n.siteKindOffice,
      SiteKind.warehouse => l10n.siteKindWarehouse,
      SiteKind.showroom => l10n.siteKindShowroom,
      SiteKind.factory => l10n.siteKindFactory,
    };

/// Markers for the active [sites]; [onTap] replaces the info window.
Set<Marker> siteMarkers(
  BuildContext context,
  MarkerIcons icons,
  Iterable<WorkSite> sites, {
  void Function(WorkSite site)? onTap,
  String? selectedId,
}) {
  final l10n = AppLocalizations.of(context);
  return {
    for (final s in sites)
      if (s.active)
        Marker(
          markerId: MarkerId('site_${s.id}'),
          position: LatLng(s.lat, s.lng),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 0,
          icon: icons.badge(
            context: context,
            icon: siteKindIcon(s.kind),
            fill: siteKindColor(s.kind),
            size: s.id == selectedId ? 36 : 30,
          ),
          infoWindow: onTap != null ? InfoWindow.noText : InfoWindow(title: s.name, snippet: siteKindLabel(s.kind, l10n)),
          onTap: onTap == null ? null : () => onTap(s),
        ),
  };
}
