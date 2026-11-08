import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/crash_reports.dart';
import '../../core/app_user.dart';
import '../../firebase_options.dart';
import 'location_tracker.dart';

/// Roles whose location the background service shares; same as
/// `UserRole.isLocationTracked` (drivers added 2026-10-20).
final _trackedRoles = {for (final r in UserRole.values) if (r.isLocationTracked) r.value};

/// Office staff whose GPS is only recorded (2026-10-28, [AppUser.recordsGps]).
final _recordedRoles = {for (final r in UserRole.values) if (r.recordsGps) r.value};

/// Starts and stops live tracking. Android: a foreground service with its own
/// isolate that survives the app being closed and restarts after reboot.
/// iOS: runs inside the app with background location updates (iOS stops it
/// if the user force-quits the app). Not used on the web.
class Tracking {
  Tracking._();

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static LocationTracker? _inApp;

  /// Android: the WorkManager watchdog (TrackingWatchdog.kt).
  static const _device = MethodChannel('wpc/device');

  /// iOS: relaunch after the app was closed (AppDelegate.swift).
  static const _ios = MethodChannel('wpc/ios_tracking');

  /// Called once at app start.
  static Future<void> configure() async {
    if (!_android) return;
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: trackingServiceMain,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        initialNotificationTitle: 'WPC CRM',
        initialNotificationContent: 'Shares your location with your team during work hours',
        foregroundServiceNotificationId: 4401,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  /// [recordOnly] / [recordDays]: office staff (iOS; the Android service
  /// reads them itself).
  static Future<void> start(String uid, {bool recordOnly = false, Set<int>? recordDays}) async {
    if (_android) {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) await service.startService();
      // Restarts the service if the phone closes it (2026-11-08).
      await _device.invokeMethod<void>('scheduleWatchdog').catchError((_) {});
    } else if (_isIos && _inApp == null) {
      // A tracker started by a background relaunch stops first (one per phone).
      await _ios.invokeMethod<void>('takeOver').catchError((_) {});
      _inApp = LocationTracker(
        uid,
        recordOnly: recordOnly,
        recordDays: recordDays,
        onDutyChanged: (on) => _ios.invokeMethod<void>('setOnDuty', on).catchError((_) {}),
        onStandby: () => _ios.invokeMethod<void>('setOnDuty', false).catchError((_) {}),
      );
      await _inApp!.start();
      // Significant location changes relaunch the app after it was closed.
      await _ios.invokeMethod<void>('enableRelaunch').catchError((_) {});
    }
  }

  /// Answers a wake ping (wake_ping.dart): Android starts the service again
  /// if it was stopped, else asks it to send a position now.
  static Future<void> wake(String uid) async {
    if (_android) {
      await configure();
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('wake');
      } else {
        await service.startService();
      }
    } else {
      await _inApp?.wake();
    }
  }

  /// Marks the user offline and stops sending. Call before signing out.
  static Future<void> stop() async {
    if (_android) await _device.invokeMethod<void>('cancelWatchdog').catchError((_) {});
    if (_isIos) await _ios.invokeMethod<void>('disableRelaunch').catchError((_) {});
    if (_android) {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) return;
      service.invoke('stop');
      for (var i = 0; i < 20 && await service.isRunning(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } else if (_inApp != null) {
      await _inApp!.stop();
      _inApp = null;
    }
  }
}

/// Entry point of the Android background service (separate isolate).
@pragma('vm:entry-point')
Future<void> trackingServiceMain(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  LocationTracker? tracker;
  var stopRequested = false;
  service.on('stop').listen((_) async {
    stopRequested = true;
    await tracker?.stop();
    await service.stopSelf();
  });
  service.on('wake').listen((_) => tracker?.wake());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setUpCrashReports('trackingService');
  final who = await _whoToTrack();
  if (who == null || stopRequested) {
    await service.stopSelf();
    return;
  }
  final (user, recorded) = who;
  final recordOnly = recorded != null;
  tracker = LocationTracker(
    user.uid,
    recordOnly: recordOnly,
    recordDays: recorded?.workSchedule?.days,
    restartedBy: await _watchdogRestart() ? 'watchdog' : null,
    onDutyChanged: (on) {
      // The service notification can't go away (Android would stop the
      // service), so off duty it says nothing is shared.
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'WPC CRM',
          content: recordOnly
              ? (on ? 'Recording your location for attendance (08:00–18:00)' : 'Off duty – your location is not recorded')
              : on
              ? 'Sharing your location with your team (work hours)'
              : 'Off duty – your location is not shared',
        );
      }
    },
    onStandby: () {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'WPC CRM',
          content: 'Not sharing – your location is shared from another phone',
        );
      }
    },
  );
  await tracker.start();
}

/// The signed-in person this phone shares / records for, else null (also
/// reached after a reboot or a relaunch). Office staff are recorded only
/// while they check attendance (users doc): their [AppUser] comes second.
Future<(User, AppUser?)?> _whoToTrack() async {
  final user = await FirebaseAuth.instance.authStateChanges().first;
  if (user == null) return null;
  final role = (await FirebaseDatabase.instance.ref('roles/${user.uid}').get()).value;
  if (_trackedRoles.contains(role)) return (user, null);
  if (!_recordedRoles.contains(role)) return null;
  try {
    final me = AppUser.fromDoc(await FirebaseFirestore.instance.doc('users/${user.uid}').get());
    if (me.recordsGps) return (user, me);
  } catch (_) {
    // Unknown: not recorded.
  }
  return null;
}

/// True when the Android watchdog started this service in the last 2 min
/// (TrackingWatchdog.kt leaves "watchdogRestartAt"); clears it.
Future<bool> _watchdogRestart() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final at = prefs.getInt('watchdogRestartAt');
    if (at == null) return false;
    await prefs.remove('watchdogRestartAt');
    return DateTime.now().millisecondsSinceEpoch - at < 2 * 60 * 1000;
  } catch (_) {
    return false;
  }
}

/// iPhone: Dart entry point of the headless engine AppDelegate.swift starts
/// when iOS relaunches the closed app for a significant location change
/// (2026-11-08). Shares like the in-app tracker until the app is opened
/// (then [Tracking.start] asks this one to stop, "takeOver").
@pragma('vm:entry-point')
Future<void> iosRelaunchMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel('wpc/ios_relaunch');
  LocationTracker? tracker;
  var stopped = false;
  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') {
      stopped = true;
      await tracker?.stop();
      tracker = null;
    }
    return null;
  });
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final who = await _whoToTrack();
  if (who == null || stopped) {
    await const MethodChannel('wpc/ios_tracking').invokeMethod<void>('disableRelaunch').catchError((_) {});
    return;
  }
  final (user, recorded) = who;
  tracker = LocationTracker(
    user.uid,
    recordOnly: recorded != null,
    recordDays: recorded?.workSchedule?.days,
    restartedBy: 'ios',
    onDutyChanged: (on) => channel.invokeMethod<void>('setOnDuty', on).catchError((_) {}),
  );
  await tracker!.start();
}
