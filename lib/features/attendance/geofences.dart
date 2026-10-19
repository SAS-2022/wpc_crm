import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    for (final g in params.geofences) {
      // Kept on the phone and sent when online if this times out.
      await recordAttendance(user.uid, type, siteId: g.id, at: now).timeout(const Duration(seconds: 20), onTimeout: () {});
    }
  } catch (e) {
    debugPrint('attendance geofence: $e');
  }
}

/// Whether the phone may report arrivals with the app closed.
Future<bool> hasAlwaysLocation() async => geofencesSupported && await Permission.locationAlways.isGranted;

const _signatureKey = 'attendanceGeofences';

/// Keeps the phone's geofences equal to the signed-in person's active work
/// sites (re-registered only when they change).
final attendanceGeofencesProvider = Provider<void>((ref) {
  if (!geofencesSupported) return;
  final me = ref.watch(currentUserProvider).value;
  final sites = ref.watch(workSitesProvider).value;
  if (me == null || sites == null) return;
  final mine = [
    for (final s in sites)
      if (me.active && s.active && me.workSiteIds.contains(s.id)) s,
  ];
  unawaited(_sync(mine));
});

/// Re-registers after the user granted "Always" (the card asks for it).
Future<void> refreshAttendanceGeofences(List<WorkSite> sites) => _sync(sites, force: true);

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
    if (!await hasAlwaysLocation()) return; // the Home card asks for it
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
