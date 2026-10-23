import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Area search on the clients map (user request 2026-10-23): "riyadh, salam"
// zooms the map to that place. Uses OpenStreetMap's free Nominatim search
// (no key, no cost; Google's Geocoding API is paid). Its usage policy: at
// most one search a second, no search-as-you-type, identify the app — so
// the map searches only when Enter / the arrow is pressed. Saudi Arabia only.

class PlaceResult {
  const PlaceResult({required this.name, required this.lat, required this.lng, this.bounds});

  final String name;
  final double lat;
  final double lng;

  /// (south, west, north, east), when the place is an area.
  final (double, double, double, double)? bounds;
}

/// The map zoom that shows [bounds] (south, west, north, east) in a map of
/// [width] × [height] logical pixels (Web Mercator, 256 px tiles), kept
/// within 5–17. The map then goes to the centre at this zoom: fitting to
/// the bounds with the map's own call zoomed out instead (2026-10-23).
double zoomForBounds((double, double, double, double) bounds, double width, double height) {
  final (south, west, north, east) = bounds;
  double latRad(double lat) {
    final sin = math.sin(lat * math.pi / 180);
    final radX2 = math.log((1 + sin) / (1 - sin)) / 2;
    return math.max(math.min(radX2, math.pi), -math.pi) / 2;
  }

  final latFraction = (latRad(north) - latRad(south)) / math.pi;
  final lngFraction = ((east - west) + 360) % 360 / 360;
  double zoomFor(double px, double fraction) =>
      fraction <= 0 ? 17 : math.log(px / 256 / fraction) / math.ln2;
  return math.min(zoomFor(height, latFraction), zoomFor(width, lngFraction)).clamp(5, 17).toDouble();
}

/// Parses a Nominatim `format=jsonv2` answer; skips entries without a point.
List<PlaceResult> parsePlaces(String body) {
  final data = jsonDecode(body);
  if (data is! List) return const [];
  double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
  return [
    for (final e in data)
      if (e is Map && n(e['lat']) != null && n(e['lon']) != null)
        PlaceResult(
          name: '${e['display_name'] ?? e['name'] ?? ''}',
          lat: n(e['lat'])!,
          lng: n(e['lon'])!,
          // [south, north, west, east] as strings.
          bounds: switch (e['boundingbox']) {
            [final s, final no, final w, final ea] when n(s) != null && n(no) != null && n(w) != null && n(ea) != null =>
              (n(s)!, n(w)!, n(no)!, n(ea)!),
            _ => null,
          },
        ),
  ];
}

/// Up to 5 places in Saudi Arabia matching [query], names in [lang]:
/// inhabited areas first (city … neighbourhood, so "riyadh, salam" finds
/// the district, not a street called Salam); nothing found → any place.
Future<List<PlaceResult>> searchPlaces(String query, {required String lang}) async {
  final areas = await _search(query, lang, areasOnly: true);
  return areas.isNotEmpty ? areas : _search(query, lang, areasOnly: false);
}

Future<List<PlaceResult>> _search(String query, String lang, {required bool areasOnly}) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query.trim(),
    'format': 'jsonv2',
    'countrycodes': 'sa',
    'limit': '5',
    'accept-language': lang,
    if (areasOnly) 'featureType': 'settlement',
  });
  // Browsers send the page as Referer (a User-Agent can't be set there).
  final res = await http.get(uri, headers: kIsWeb ? const {} : const {'User-Agent': 'WPC-CRM/1.0 (wpc-crm-a9247.web.app)'});
  if (res.statusCode != 200) throw Exception('Place search failed (${res.statusCode})');
  return parsePlaces(utf8.decode(res.bodyBytes));
}
