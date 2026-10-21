import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../firebase_options.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';

// Automatic check-in / check-out (user decision 2026-10-19: geofences). The
// phone registers its person's work sites with the OS (Android
// GeofencingClient / iOS region monitoring), which wakes the app only when
// they enter or leave a site, even when the app is closed. Nothing is tracked
// anywhere else. Needs location permission "Always".

bool get geofencesSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Called by the OS (in the background, possibly with the app closed).
@pragma('vm:entry-point')
Future<void> attendanceGeofenceTriggered(GeofenceCallbackParams params) async {
  DartPluginRegistrant.ensureInitialized();
  final type = switch (params.event) {
    GeofenceEvent.enter => AttendanceEventType.in_,
    GeofenceEvent.exit => AttendanceEventType.out,
    _ => null,
  };
  if (type == null) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    final now = DateTime.now();
    final fix = await _freshFix();
    for (final g in params.geofences) {
      Map<String, Object>? extra;
      if (fix != null) {
        final distance = Geolocator.distanceBetween(fix.latitude, fix.longitude, g.location.latitude, g.location.longitude);
        if (!geofenceEventConfirmed(
          enter: type == AttendanceEventType.in_,
          distance: distance,
          accuracy: fix.accuracy,
          radius: g.radiusMeters,
        )) {
          debugPrint('attendance geofence: ${params.event.name} at ${g.id} ignored, GPS ${distance.round()} m');
          continue;
        }
        extra = {'dist': distance.round(), 'acc': fix.accuracy.round()};
      }
      // Kept on the phone and sent when online if this times out.
      await recordAttendance(user.uid, type, siteId: g.id, at: now, extra: extra)
          .timeout(const Duration(seconds: 20), onTimeout: () {});
    }
  } catch (e) {
    debugPrint('attendance geofence: $e');
  }
}

/// A GPS fix to confirm a geofence event; null when none comes in time
/// (the event is then trusted).
Future<Position?> _freshFix() async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
    );
  } catch (e) {
    debugPrint('attendance geofence: no GPS fix: $e');
    return null;
  }
}

/// Whether the phone may report arrivals with the app closed.
Future<bool> hasAlwaysLocation() async => geofencesSupported && await Permission.locationAlways.isGranted;

const _signatureKey = 'attendanceGeofences';

/// Registered once since the app started.
var _registeredThisLaunch = false;

/// Keeps the phone's geofences equal to the signed-in person's active work
/// sites: registered again at every app start (Android drops them when the
/// app is force-stopped — Xiaomi does that when it's swiped away — after a
/// reboot or when location is switched off; found 2026-10-21), otherwise
/// only when the sites change. Already at a site when registered counts as
/// arriving.
final attendanceGeofencesProvider = Provider<void>((ref) {
  if (!geofencesSupported) return;
  final me = ref.watch(currentUserProvider).value;
  final sites = ref.watch(workSitesProvider).value;
  if (me == null || sites == null) return;
  final mine = [
    for (final s in sites)
      if (me.active && me.needsAttendance && s.active && me.workSiteIds.contains(s.id)) s,
  ];
  final force = !_registeredThisLaunch;
  _registeredThisLaunch = true;
  unawaited(_sync(mine, force: force));
});

/// Re-registers after the user granted "Always" (the card asks for it).
Future<void> refreshAttendanceGeofences(List<WorkSite> sites) => _sync(sites, force: true);

/// Registers the sites if they aren't yet (e.g. "Always" was granted while
/// the app was in the phone's settings). Cheap when nothing changed.
Future<void> ensureAttendanceGeofences(List<WorkSite> sites) => _sync(sites);

Future<void> _sync(List<WorkSite> sites, {bool force = false}) async {
  try {
    final signature = [for (final s in sites) '${s.id}:${s.lat}:${s.lng}:${s.radius}'].join('|');
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getString(_signatureKey) == signature) return;
    final manager = NativeGeofenceManager.instance;
    await manager.initialize();
    await manager.removeAllGeofences();
    if (sites.isEmpty) {
      await prefs.setString(_signatureKey, signature);
      return;
    }
    if (!await hasAlwaysLocation()) {
      // Nothing registered: the next sync (e.g. back from the settings with
      // "Always" granted) must register again (found 2026-10-21).
      await prefs.remove(_signatureKey);
      return; // the Home card asks for it
    }
    for (final s in sites) {
      await manager.createGeofence(
        Geofence(
          id: s.id,
          location: Location(latitude: s.lat, longitude: s.lng),
          radiusMeters: s.radius,
          triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
          // Already at the site when registered: counts as arriving.
          iosSettings: const IosGeofenceSettings(initialTrigger: true),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {GeofenceEvent.enter},
            notificationResponsiveness: Duration(minutes: 1),
          ),
        ),
        attendanceGeofenceTriggered,
      );
    }
    await prefs.setString(_signatureKey, signature);
  } catch (e) {
    debugPrint('attendance geofences: $e');
  }
}
