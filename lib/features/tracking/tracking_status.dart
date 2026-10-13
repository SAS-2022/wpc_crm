import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/providers.dart';
import 'tracking_service.dart';

/// Things that stop tracking from being complete, in the order to fix them.
enum TrackingIssue { gpsOff, locationDenied, notAlways, notifications, battery }

class TrackingStatus {
  const TrackingStatus({required this.running, required this.issues});

  final bool running;
  final List<TrackingIssue> issues;
}

bool get _android => defaultTargetPlatform == TargetPlatform.android;

/// For sales executives and KAMs: checks permissions and starts tracking.
/// null for everyone else (and on the web). Kept alive by the app widget.
final trackingStatusProvider = FutureProvider<TrackingStatus?>((ref) async {
  final me = ref.watch(currentUserProvider).value;
  if (kIsWeb || me == null) return null;
  if (!me.active || !me.role.isTracked) {
    await Tracking.stop();
    return null;
  }
  final issues = await checkTrackingIssues();
  final canRun = !issues.contains(TrackingIssue.locationDenied);
  if (canRun) await Tracking.start(me.id);
  return TrackingStatus(running: canRun, issues: issues);
});

Future<List<TrackingIssue>> checkTrackingIssues() async {
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
  }
}
