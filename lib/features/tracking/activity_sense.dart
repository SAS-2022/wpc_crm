import 'dart:async';

import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// The phone's own motion sensing (user request 2026-10-31: tell walking from
/// driving so walking isn't added to a vehicle's km). Android's Activity
/// Recognition / iOS Core Motion use the motion sensors, not GPS, and cost
/// little battery. Drivers only for now.
///
/// Each route point carries the latest detection as `a` ([activityCode]);
/// the server's `dayDistances` (functions/vehicles.js) trusts it over speed.

/// Detections older than this aren't sent (the phone reports changes, and
/// stops reporting while it lies still for long).
const activityMaxAge = Duration(minutes: 5);

/// Less sure than this (0–100) = not sent.
const activityMinConfidence = 50;

/// 'v' in a vehicle, 'f' on foot (walking / running), 's' still, 'b' on a
/// bicycle; null when unknown, unsure or too old.
String? activityCode(ActivityType type, int confidence, DateTime at, DateTime now) {
  if (confidence < activityMinConfidence || now.difference(at) > activityMaxAge) return null;
  return switch (type) {
    ActivityType.IN_VEHICLE => 'v',
    ActivityType.ON_FOOT || ActivityType.WALKING || ActivityType.RUNNING => 'f',
    ActivityType.STILL => 's',
    ActivityType.ON_BICYCLE => 'b',
    ActivityType.TILTING || ActivityType.UNKNOWN => null,
  };
}

/// The permission the motion sensing needs: Android "Physical activity",
/// iOS "Motion & Fitness".
Permission get activityPermission =>
    defaultTargetPlatform == TargetPlatform.iOS ? Permission.sensors : Permission.activityRecognition;

class ActivitySense {
  StreamSubscription<ActivityEvent>? _sub;
  ActivityEvent? _last;
  DateTime? _receivedAt;

  bool get running => _sub != null;

  /// Starts when the permission is given; safe to call again (e.g. every
  /// heartbeat, so a permission given later starts it).
  Future<void> start() async {
    if (_sub != null || kIsWeb) return;
    try {
      if (!await activityPermission.isGranted) return;
      // The tracking service is already a foreground service: no second one.
      _sub = ActivityRecognition().activityStream(runForegroundService: false).listen((e) {
        _last = e;
        _receivedAt = DateTime.now();
      }, onError: (_) {});
    } catch (_) {
      // No sensor / Play services: points go without it.
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _last = null;
    _receivedAt = null;
  }

  /// The latest detection as [activityCode]; aged from when it arrived (the
  /// platform's own time stamp may use another clock).
  String? get code {
    final e = _last, at = _receivedAt;
    if (e == null || at == null) return null;
    return activityCode(e.type, e.confidence, at, DateTime.now());
  }
}
