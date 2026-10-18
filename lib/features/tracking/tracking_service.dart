import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../firebase_options.dart';
import 'location_tracker.dart';

const _trackedRoles = {'sales_exec', 'kam'};

/// Starts and stops live tracking. Android: a foreground service with its own
/// isolate that survives the app being closed and restarts after reboot.
/// iOS: runs inside the app with background location updates (iOS stops it
/// if the user force-quits the app). Not used on the web.
class Tracking {
  Tracking._();

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static LocationTracker? _inApp;

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

  static Future<void> start(String uid) async {
    if (_android) {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) await service.startService();
    } else if (_ios && _inApp == null) {
      _inApp = LocationTracker(uid);
      await _inApp!.start();
    }
  }

  /// Marks the user offline and stops sending. Call before signing out.
  static Future<void> stop() async {
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final user = await FirebaseAuth.instance.authStateChanges().first;
  // Also reached after a reboot: only track signed-in field staff.
  final role = user == null ? null : (await FirebaseDatabase.instance.ref('roles/${user.uid}').get()).value;
  if (user == null || !_trackedRoles.contains(role) || stopRequested) {
    await service.stopSelf();
    return;
  }
  tracker = LocationTracker(
    user.uid,
    onDutyChanged: (on) {
      // The service notification can't go away (Android would stop the
      // service), so off duty it says nothing is shared.
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'WPC CRM',
          content: on ? 'Sharing your location with your team (work hours)' : 'Off duty – your location is not shared',
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
