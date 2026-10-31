import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import 'activity_sense.dart';
import 'tracking_service.dart';

/// Things that stop tracking from being complete, in the order to fix them.
/// [motion]: drivers only, the motion sensing that tells walking from driving.
enum TrackingIssue { gpsOff, locationDenied, notAlways, notifications, battery, motion }

class TrackingStatus {
  const TrackingStatus({required this.running, required this.issues});

  final bool running;
  final List<TrackingIssue> issues;
}

bool get _android => defaultTargetPlatform == TargetPlatform.android;

/// For sales executives, KAMs and drivers: checks permissions and starts tracking;
/// office staff who check attendance: GPS recorded only ([AppUser.recordsGps],
/// 2026-10-28). null for everyone else (and on the web). Kept alive by the app widget.
final trackingStatusProvider = FutureProvider<TrackingStatus?>((ref) async {
  final me = ref.watch(currentUserProvider).value;
  if (kIsWeb || me == null) return null;
  final recordOnly = !me.role.isLocationTracked && me.recordsGps;
  if (!me.active || !(me.role.isLocationTracked || recordOnly)) {
    await Tracking.stop();
    return null;
  }
  final issues = await checkTrackingIssues(driver: me.role == UserRole.driver);
  final canRun = !issues.contains(TrackingIssue.locationDenied);
  if (canRun) await Tracking.start(me.id, recordOnly: recordOnly, recordDays: me.workSchedule?.days);
  return TrackingStatus(running: canRun, issues: issues);
});

Future<List<TrackingIssue>> checkTrackingIssues({bool driver = false}) async {
  final issues = <TrackingIssue>[];
  if (!await Geolocator.isLocationServiceEnabled()) issues.add(TrackingIssue.gpsOff);
  if (!await Permission.locationWhenInUse.isGranted) {
    issues.add(TrackingIssue.locationDenied);
  } else if (!await Permission.locationAlways.isGranted) {
    issues.add(TrackingIssue.notAlways);
  }
  if (_android) {
    if (!await Permission.notification.isGranted) issues.add(TrackingIssue.notifications);
    if (!await Permission.ignoreBatteryOptimizations.isGranted) issues.add(TrackingIssue.battery);
  }
  if (driver && !await activityPermission.isGranted) issues.add(TrackingIssue.motion);
  return issues;
}

Future<void> fixTrackingIssue(TrackingIssue issue) async {
  switch (issue) {
    case TrackingIssue.gpsOff:
      await Geolocator.openLocationSettings();
    case TrackingIssue.locationDenied:
      final status = await Permission.locationWhenInUse.request();
      if (status.isPermanentlyDenied) await openAppSettings();
    case TrackingIssue.notAlways:
      // Android 11+ opens the settings page where "Allow all the time" is chosen.
      final status = await Permission.locationAlways.request();
      if (status.isPermanentlyDenied) await openAppSettings();
    case TrackingIssue.notifications:
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) await openAppSettings();
    case TrackingIssue.battery:
      await Permission.ignoreBatteryOptimizations.request();
    case TrackingIssue.motion:
      final status = await activityPermission.request();
      if (status.isPermanentlyDenied) await openAppSettings();
  }
}
