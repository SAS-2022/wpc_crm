import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import 'location.dart';

/// Riyadh, used when there is nothing to show yet.
const defaultMapCenter = LatLng(24.7136, 46.6753);

/// Closest zoom when fitting markers, so one or two close pins don't end up
/// at rooftop level.
const _fitMaxZoom = 16.0;

/// The user's current position, or null when GPS isn't available.
Future<LatLng?> locateMe() async {
  try {
    final position = (await currentPosition()).position;
    return position == null ? null : LatLng(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

/// Moves the camera to show every point (street level for a single one).
Future<void> fitPoints(GoogleMapController map, List<LatLng> points, {double padding = 56}) async {
  if (points.isEmpty) return;
  if (points.length == 1) {
    await map.animateCamera(CameraUpdate.newLatLngZoom(points.single, 15));
    return;
  }
  var south = points.first.latitude, north = south;
  var west = points.first.longitude, east = west;
  for (final p in points.skip(1)) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  await map.animateCamera(
    CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)), padding),
  );
  if (await map.getZoomLevel() > _fitMaxZoom) {
    await map.animateCamera(CameraUpdate.zoomTo(_fitMaxZoom));
  }
}

/// Round marker images (letter, number or initials on a coloured circle),
/// drawn once per look and reused. Until an image is ready the marker shows
/// a default pin, and [onReady] is called so the map can rebuild.
class MarkerIcons {
  MarkerIcons(this.onReady);

  final VoidCallback onReady;
  final _cache = <String, BitmapDescriptor>{};
  final _pending = <String>{};

  /// [fill] circle with [text] in [textColor], inside a [ring] of [ringWidth].
  BitmapDescriptor circle({
    required BuildContext context,
    required Color fill,
    required String text,
    Color textColor = Colors.white,
    Color ring = Colors.white,
    double ringWidth = 2,
    double size = 30,
  }) {
    final key = '${fill.toARGB32()}|$text|${textColor.toARGB32()}|${ring.toARGB32()}|$ringWidth|$size';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_pending.add(key)) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      _draw(fill, text, textColor, ring, ringWidth, size, ratio).then((icon) {
        _cache[key] = icon;
        _pending.remove(key);
        onReady();
      });
    }
    return BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(fill).hue);
  }

  static Future<BitmapDescriptor> _draw(
    Color fill,
    String text,
    Color textColor,
    Color ring,
    double ringWidth,
    double size,
    double ratio,
  ) async {
    const shadow = 2.0;
    final full = size + shadow * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    final center = Offset(full / 2, full / 2);
    final radius = size / 2;
    canvas.drawCircle(
      center.translate(0, 1),
      radius,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadow),
    );
    canvas.drawCircle(center, radius, Paint()..color = ring);
    canvas.drawCircle(center, radius - ringWidth, Paint()..color = fill);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: size * (text.length > 1 ? 0.38 : 0.45),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    final px = (full * ratio).ceil();
    final image = await recorder.endRecording().toImage(px, px);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(png!.buffer.asUint8List(), imagePixelRatio: ratio);
  }
}

/// My location, zoom in, zoom out and (optionally) show-all buttons, stacked
/// at the bottom end of a map.
class MapControls extends StatelessWidget {
  const MapControls({super.key, required this.map, required this.onMyLocation, this.onFitAll});

  /// Null until the map has been created.
  final GoogleMapController? map;
  final VoidCallback onMyLocation;
  final VoidCallback? onFitAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(top: 8),
      // No hero: several maps can be open in the tab stacks at once.
      child: FloatingActionButton.small(heroTag: null, tooltip: tooltip, onPressed: onPressed, child: Icon(icon)),
    );
    // On the web the map is a browser element under Flutter's layer; without
    // this, clicks on the buttons also reach the map (a double click on "+"
    // zoomed in towards the button).
    return PointerInterceptor(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.my_location, l10n.myLocation, onMyLocation),
          button(Icons.add, l10n.zoomIn, () => map?.animateCamera(CameraUpdate.zoomIn())),
          button(Icons.remove, l10n.zoomOut, () => map?.animateCamera(CameraUpdate.zoomOut())),
          if (onFitAll != null) button(Icons.zoom_out_map, l10n.showAllClients, onFitAll!),
        ],
      ),
    );
  }
}
