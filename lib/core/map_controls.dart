import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Map / satellite / hybrid view of every map, remembered on this device.
final mapTypeProvider = NotifierProvider<MapTypeController, MapType>(MapTypeController.new);

class MapTypeController extends Notifier<MapType> {
  static const _key = 'mapType';

  @override
  MapType build() {
    _load();
    return MapType.normal;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final type = MapType.values.where((t) => t.name == saved).firstOrNull;
      if (type != null) state = type;
    } catch (_) {
      // Default view.
    }
  }

  Future<void> set(MapType type) async {
    state = type;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, type.name);
    } catch (_) {
      // Kept for this session only.
    }
  }
}

/// The views offered by [MapTypeButton].
const mapTypeChoices = [MapType.normal, MapType.satellite, MapType.hybrid];

/// Small round button that picks the map view. Uses the shared
/// [mapTypeProvider] unless [value] / [onChanged] are given.
class MapTypeButton extends ConsumerWidget {
  const MapTypeButton({super.key, this.value, this.onChanged});

  final MapType? value;
  final ValueChanged<MapType>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final MapType current = value ?? ref.watch(mapTypeProvider);
    String label(MapType t) => switch (t) {
          MapType.satellite => l10n.mapViewSatellite,
          MapType.hybrid => l10n.mapViewHybrid,
          _ => l10n.mapViewMap,
        };
    IconData icon(MapType t) => switch (t) {
          MapType.satellite => Icons.satellite_alt_outlined,
          MapType.hybrid => Icons.layers_outlined,
          _ => Icons.map_outlined,
        };
    return PointerInterceptor(
      child: PopupMenuButton<MapType>(
        tooltip: l10n.mapView,
        initialValue: current,
        // Root navigator: the menu scrolls to the ticked item, which would
        // also scroll the tab pager around a tab's navigator.
        useRootNavigator: true,
        onSelected: (t) => onChanged != null ? onChanged!(t) : ref.read(mapTypeProvider.notifier).set(t),
        itemBuilder: (_) => [
          for (final t in mapTypeChoices)
            PopupMenuItem(
              value: t,
              // Clicks on the menu must not reach the web map under it.
              child: PointerInterceptor(
                child: Row(
                  children: [
                    Icon(icon(t), size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label(t))),
                    if (t == current) const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            ),
        ],
        child: Material(
          elevation: 3,
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: SizedBox(width: 40, height: 40, child: Icon(icon(current), size: 22)),
        ),
      ),
    );
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

/// How much pins shrink when zoomed out (user 2026-11-12: zoomed out, client
/// and salespeople pins covered the map). Steps, so only a few sizes are drawn.
double markerScaleForZoom(double zoom) => zoom >= 13
    ? 1.0
    : zoom >= 11
        ? 0.8
        : zoom >= 9
            ? 0.62
            : 0.48;

/// Pins drawn smaller than this leave out their letter / initials.
const _minTextSize = 17.0;

/// Round marker images (letter, number or initials on a coloured circle),
/// drawn once per look and reused. Until an image is ready the marker shows
/// a default pin, and [onReady] is called so the map can rebuild.
///
/// Sizes follow the map's zoom: pass [zoomChanged] to the map's
/// `onCameraMove` and the pins shrink when zoomed out ([markerScaleForZoom]).
class MarkerIcons {
  MarkerIcons(this.onReady, {double zoom = 15}) : _scale = markerScaleForZoom(zoom);

  final VoidCallback onReady;
  final _cache = <String, BitmapDescriptor>{};
  final _pending = <String>{};
  double _scale;

  /// Current size factor of the pins.
  double get scale => _scale;

  /// For `GoogleMap.onCameraMove`; rebuilds the map only when the size step changes.
  void zoomChanged(CameraPosition position) {
    final next = markerScaleForZoom(position.zoom);
    if (next == _scale) return;
    _scale = next;
    onReady();
  }

  /// [fill] circle with [text] in [textColor], inside a [ring] of [ringWidth].
  /// [size] is the size at street level; [scaled] false keeps it at any zoom.
  BitmapDescriptor circle({
    required BuildContext context,
    required Color fill,
    required String text,
    Color textColor = Colors.white,
    Color ring = Colors.white,
    double ringWidth = 2,
    double size = 30,
    bool scaled = true,
  }) {
    final factor = scaled ? _scale : 1.0;
    final drawn = size * factor;
    final shown = drawn < _minTextSize ? '' : text;
    final ringDrawn = factor == 1 ? ringWidth : math.max(1.0, ringWidth * factor);
    final key = 'c|${fill.toARGB32()}|$shown|${textColor.toARGB32()}|${ring.toARGB32()}|$ringDrawn|$drawn';
    return _get(key, context, (ratio) => _drawCircle(fill, shown, textColor, ring, ringDrawn, drawn, ratio),
        () => BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(fill).hue));
  }

  /// Rounded square with a white [icon] on [fill] (work sites, 2026-11-12).
  BitmapDescriptor badge({required BuildContext context, required IconData icon, required Color fill, double size = 30}) {
    final drawn = math.max(18.0, size * _scale);
    final key = 'b|${icon.codePoint}|${icon.fontFamily}|${fill.toARGB32()}|$drawn';
    return _get(key, context, (ratio) => _drawBadge(icon, fill, drawn, ratio),
        () => BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(fill).hue));
  }

  BitmapDescriptor _get(
    String key,
    BuildContext context,
    Future<BitmapDescriptor> Function(double ratio) draw,
    BitmapDescriptor Function() placeholder,
  ) {
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_pending.add(key)) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      draw(ratio).then((icon) {
        _cache[key] = icon;
        _pending.remove(key);
        onReady();
      });
    }
    return placeholder();
  }

  static Future<BitmapDescriptor> _drawCircle(
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
    if (text.isNotEmpty) {
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
    }
    return _toDescriptor(recorder, full, ratio);
  }

  static Future<BitmapDescriptor> _drawBadge(IconData icon, Color fill, double size, double ratio) async {
    const shadow = 2.0;
    final full = size + shadow * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    final rect = Rect.fromLTWH(shadow, shadow, size, size);
    final corner = Radius.circular(size * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 1), corner),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadow),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, corner), Paint()..color = Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(2), Radius.circular(size * 0.18)), Paint()..color = fill);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size * 0.62,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, rect.center - Offset(painter.width / 2, painter.height / 2));
    return _toDescriptor(recorder, full, ratio);
  }

  static Future<BitmapDescriptor> _toDescriptor(ui.PictureRecorder recorder, double full, double ratio) async {
    final px = (full * ratio).ceil();
    final image = await recorder.endRecording().toImage(px, px);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(png!.buffer.asUint8List(), imagePixelRatio: ratio);
  }
}

/// Map view, my location, zoom in, zoom out and (optionally) show-all buttons, stacked
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
          const MapTypeButton(),
          button(Icons.my_location, l10n.myLocation, onMyLocation),
          button(Icons.add, l10n.zoomIn, () => map?.animateCamera(CameraUpdate.zoomIn())),
          button(Icons.remove, l10n.zoomOut, () => map?.animateCamera(CameraUpdate.zoomOut())),
          if (onFitAll != null) button(Icons.zoom_out_map, l10n.showAllClients, onFitAll!),
        ],
      ),
    );
  }
}
