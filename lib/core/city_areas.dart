import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import 'map_controls.dart' show fitPoints;
import 'place_search.dart';

/// Saudi regions as quick map buttons (user request 2026-11-04, replaces the
/// Riyadh / Jeddah / Dammam city buttons of 2026-11-01): a tap keeps only the
/// pins inside the region and zooms to them, tapping again shows everything.
/// Pins are matched by coordinates, not by the typed city name, which is
/// often empty or spelled differently.
///
/// The borders are simple longitude lines that bend with the latitude, close
/// to the provinces: Western = Makkah, Madinah, Tabuk, Al Baha, Asir, Jazan,
/// Najran (Jeddah, Makkah, Madinah, Taif, Tabuk, Abha, Jazan); Eastern = the
/// Eastern Province (Dammam, Khobar, Jubail, Al Ahsa, Hafar Al Batin);
/// Central = the rest (Riyadh, Qassim, Hail, …).
enum SaudiRegion {
  eastern((15.5, 45.0, 32.5, 56.0)),
  central((17.0, 40.5, 32.0, 50.0)),
  western((15.5, 34.0, 32.0, 44.8));

  const SaudiRegion(this.box);

  /// (south, west, north, east): the view when no pin is inside.
  final (double, double, double, double) box;

  /// West border of the Eastern region: further west in the north so Hafar
  /// Al Batin is Eastern while Majmaah and Zulfi stay Central.
  static double _eastFrom(double lat) => lat > 27.0 ? 45.5 : 47.8;

  /// East border of the Western region: further east in the south (Abha,
  /// Khamis Mushait, Jazan, Najran), further west in the north (Hail is Central).
  static double _westTo(double lat) => lat < 20.5 ? 44.5 : (lat < 26.0 ? 42.0 : 41.0);

  /// The region [lat], [lng] falls in; null outside Saudi Arabia (roughly).
  static SaudiRegion? of(double lat, double lng) {
    if (lat < 15.5 || lat > 32.5 || lng < 34.0 || lng > 56.0) return null;
    if (lng >= _eastFrom(lat)) return eastern;
    if (lng < _westTo(lat)) return western;
    return central;
  }

  bool contains(double lat, double lng) => of(lat, lng) == this;

  String label(AppLocalizations l10n) => switch (this) {
        eastern => l10n.regionEastern,
        central => l10n.regionCentral,
        western => l10n.regionWestern,
      };

  /// Moves [map] (of [size] logical pixels, less what covers it) to the
  /// region's [points], or to the whole region when there are none.
  void zoomTo(GoogleMapController? map, Size size, [List<LatLng> points = const []]) {
    if (map == null) return;
    if (points.isNotEmpty) {
      fitPoints(map, points, padding: 48);
      return;
    }
    final (s, w, n, e) = box;
    map.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng((s + n) / 2, (w + e) / 2),
      zoomForBounds(box, math.max(size.width - 48, 160), math.max(size.height - 200, 160)),
    ));
  }
}

/// The region buttons in a row; [selected] null = everywhere.
class RegionChips extends StatelessWidget {
  const RegionChips({super.key, required this.selected, required this.onSelected});

  final SaudiRegion? selected;
  final ValueChanged<SaudiRegion?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PointerInterceptor(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in SaudiRegion.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.explore_outlined, size: 16),
                  label: Text(r.label(l10n)),
                  selected: selected == r,
                  onSelected: (on) => onSelected(on ? r : null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
