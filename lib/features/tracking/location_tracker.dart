import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// How often a position is sent (user decision: every 2 minutes).
const trackingInterval = Duration(minutes: 2);

/// Sends the user's position to RTDB every [trackingInterval] and keeps their
/// presence honest: the server marks them offline as soon as the connection
/// drops, and a heartbeat reports when GPS is off even without new fixes.
class LocationTracker {
  LocationTracker(this.uid);

  final String uid;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _heartbeat;
  DateTime? _lastSent;

  DatabaseReference get _presence => FirebaseDatabase.instance.ref('presence/$uid');

  Future<void> start() async {
    _subscriptions.add(FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      // Registered on the server: runs when the phone disconnects
      // (no signal, switched off, app killed).
      await _presence.onDisconnect().update({'online': false, 'lastSeen': ServerValue.timestamp});
      await _presence.update({'online': true, 'lastSeen': ServerValue.timestamp});
    }));
    _subscriptions.add(Geolocator.getPositionStream(locationSettings: _settings()).listen(
      _send,
      onError: (_) => _beat(),
    ));
    _heartbeat = Timer.periodic(trackingInterval, (_) => _beat());
    await _beat();
  }

  Future<void> stop() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _heartbeat?.cancel();
    await _presence.onDisconnect().cancel();
    await _presence.update({'online': false, 'lastSeen': ServerValue.timestamp});
  }

  Future<void> _beat() async {
    var gpsOn = false;
    var permission = LocationPermission.denied;
    try {
      gpsOn = await Geolocator.isLocationServiceEnabled();
      permission = await Geolocator.checkPermission();
    } catch (_) {
      // Reported as GPS off / denied.
    }
    await _presence.update({
      'lastSeen': ServerValue.timestamp,
      'gpsOn': gpsOn,
      'permission': permission.name,
    });
  }

  Future<void> _send(Position p) async {
    final now = DateTime.now();
    // The OS may deliver fixes more often than asked for; keep one per interval.
    if (_lastSent != null && now.difference(_lastSent!) < trackingInterval - const Duration(seconds: 15)) return;
    _lastSent = now;
    final point = {
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'mocked': p.isMocked,
    };
    await FirebaseDatabase.instance.ref('live_locations/$uid').set({
      ...point,
      'speed': p.speed,
      'fixAt': p.timestamp.millisecondsSinceEpoch,
      'updatedAt': ServerValue.timestamp,
    });
    // Route history per day, for the dashboard (distance, time in the field).
    final day = DateFormat('yyyy-MM-dd').format(now);
    await FirebaseDatabase.instance.ref('location_history/$uid/$day').push().set({
      ...point,
      't': ServerValue.timestamp,
    });
  }

  LocationSettings _settings() => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: trackingInterval,
          ),
        TargetPlatform.iOS => AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            activityType: ActivityType.otherNavigation,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          ),
        _ => const LocationSettings(accuracy: LocationAccuracy.high),
      };
}
