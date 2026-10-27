import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/crash_reports.dart';
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
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await setUpCrashReports('geofence');
    }
    final user = await FirebaseAuth.instance.authStateChanges().first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    // Signed out (2026-10-22: arrivals were lost while signed out, so signing
    // in later counted as arriving then): kept on the phone for the person
    // whose sites these are, sent with their real time at the next sign-in.
    final owner = user?.uid ?? prefs.getString(_ownerKey);
    if (owner == null) return;
    final now = DateTime.now();
    final fix = await freshAttendanceFix();
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
      if (user == null) {
        await _queue(prefs, owner, type, g.id, now, extra);
        continue;
      }
      // Kept on the phone and sent when online if this times out.
      await recordAttendance(user.uid, type, siteId: g.id, at: now, extra: extra)
          .timeout(const Duration(seconds: 20), onTimeout: () {});
    }
  } catch (e) {
    debugPrint('attendance geofence: $e');
  }
}

/// A GPS fix to confirm a geofence event or answer a site check; null when
/// none comes in time (a geofence event is then trusted).
Future<Position?> freshAttendanceFix() async {
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

/// Whose sites the registered geofences are (the last person signed in).
const _ownerKey = 'attendanceGeofencesOwner';

/// Events that came while nobody was signed in: [{uid, type, siteId, at, extra}].
const _queueKey = 'attendancePendingEvents';

Future<void> _queue(SharedPreferences prefs, String uid, AttendanceEventType type, String siteId, DateTime at,
    Map<String, Object>? extra) async {
  await prefs.reload();
  final list = [...prefs.getStringList(_queueKey) ?? const <String>[]];
  list.add(jsonEncode({
    'uid': uid,
    'type': eventTypeKey(type),
    'siteId': siteId,
    'at': at.millisecondsSinceEpoch,
    'extra': {...?extra, 'queued': true},
  }));
  await prefs.setStringList(_queueKey, list);
}

/// Sends [uid]'s events kept while signed out, with their real times; older
/// than 3 days or someone else's are dropped.
Future<void> _flushQueue(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // written by the background callback's isolate
  final list = prefs.getStringList(_queueKey);
  if (list == null || list.isEmpty) return;
  await prefs.remove(_queueKey);
  final oldest = DateTime.now().subtract(const Duration(days: 3));
  for (final raw in list) {
    try {
      final e = jsonDecode(raw) as Map<String, dynamic>;
      final type = eventTypeFromKey(e['type']);
      final at = DateTime.fromMillisecondsSinceEpoch(e['at'] as int);
      if (e['uid'] != uid || type == null || at.isBefore(oldest)) continue;
      await recordAttendance(uid, type, siteId: e['siteId'] as String?, at: at, extra: (e['extra'] as Map).cast<String, Object>());
    } catch (err) {
      debugPrint('attendance queue: $err');
    }
  }
}

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
  final sitesValue = ref.watch(workSitesProvider);
  // Still loading (e.g. right after sign-in, with the signed-out empty list
  // as the old value): wait, so the geofences aren't dropped meanwhile.
  final sites = sitesValue.isLoading ? null : sitesValue.value;
  if (me == null || sites == null) return;
  final mine = [
    for (final s in sites)
      if (me.active && me.needsAttendance && s.active && me.workSiteIds.contains(s.id)) s,
  ];
  final force = !_registeredThisLaunch;
  _registeredThisLaunch = true;
  unawaited(() async {
    // First what happened while signed out, so a re-registration's "already
    // inside" doesn't become the day's first arrival.
    await _flushQueue(me.id);
    await (await SharedPreferences.getInstance()).setString(_ownerKey, me.id);
    await _sync(mine, force: force);
  }());
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
