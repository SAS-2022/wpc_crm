import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'work_hours.dart';

/// How often a position is sent (user decision: every 2 minutes).
const trackingInterval = Duration(minutes: 2);

/// Sends the user's position to RTDB every [trackingInterval] during work
/// hours ([WorkHours]) and keeps their presence honest: the server marks them
/// offline as soon as the connection drops, and a heartbeat reports when GPS
/// is off even without new fixes. Outside work hours nothing is sent and the
/// live position is removed.
class LocationTracker {
  LocationTracker(this.uid);

  final String uid;
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<Position>? _positions;
  Timer? _heartbeat;
  Timer? _dutyCheck;
  DateTime? _lastSent;
  WorkHours _hours = WorkHours.defaults;

  /// null until first checked.
  bool? _onDuty;

  DatabaseReference get _presence => FirebaseDatabase.instance.ref('presence/$uid');

  Future<void> start() async {
    _subscriptions.add(FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      // Registered on the server: runs when the phone disconnects
      // (no signal, switched off, app killed).
      await _presence.onDisconnect().update({'online': false, 'lastSeen': ServerValue.timestamp});
      await _presence.update({'online': true, 'lastSeen': ServerValue.timestamp});
    }));
    _subscriptions.add(workHoursRef.onValue.listen((event) {
      _hours = WorkHours.fromMap(event.snapshot.value);
      _applyDuty();
    }));
    _dutyCheck = Timer.periodic(const Duration(minutes: 1), (_) => _applyDuty());
    _heartbeat = Timer.periodic(trackingInterval, (_) => _beat());
    await _applyDuty();
    await _beat();
  }

  /// Switches between sharing (work hours) and not sharing.
  Future<void> _applyDuty() async {
    final on = _hours.isOn(DateTime.now());
    if (on == _onDuty) return;
    _onDuty = on;
    await _positions?.cancel();
    // Off duty a coarse, low-power stream keeps iOS from suspending the app
    // (so sharing resumes on its own when work starts); its fixes are dropped.
    _positions = Geolocator.getPositionStream(locationSettings: on ? _settings() : _idleSettings()).listen(
      on ? _send : (_) {},
      onError: (_) => _beat(),
    );
    if (!on) {
      _lastSent = null;
      await FirebaseDatabase.instance.ref('live_locations/$uid').remove();
    }
    await _presence.update({'onDuty': on});
  }

  Future<void> stop() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _positions?.cancel();
    _positions = null;
    _onDuty = null;
    _heartbeat?.cancel();
    _dutyCheck?.cancel();
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
    if (_onDuty != true) return;
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

  LocationSettings _idleSettings() => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.lowest,
            distanceFilter: 5000,
            intervalDuration: const Duration(minutes: 30),
          ),
        TargetPlatform.iOS => AppleSettings(
            accuracy: LocationAccuracy.lowest,
            distanceFilter: 5000,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: false,
          ),
        _ => const LocationSettings(accuracy: LocationAccuracy.lowest, distanceFilter: 5000),
      };
}
