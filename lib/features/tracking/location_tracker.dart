import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'tracking_device.dart';
import 'work_hours.dart';
import 'motion.dart';
import 'device_health.dart';
import 'tracking_schedule.dart';
import '../settings/app_settings.dart';

/// How often a position is sent by default (user decision 2026-10-18: every
/// 30 seconds; was 2 minutes). Editable in App settings (RTDB
/// `settings/app/trackingIntervalSec`, [AppSetting.trackingIntervalSec]).
const trackingInterval = Duration(seconds: 30);

/// How often GPS / permission / battery / notification state is re-checked.
/// Each presence write runs the `trackingAlerts` Cloud Function, so it stays
/// slower than the position updates.
const heartbeatInterval = Duration(minutes: 2);

/// Sends the user's position to RTDB every [trackingInterval] (or the App
/// settings value) during work hours ([WorkHours], or the person's own
/// [TrackingSchedule]) and keeps their presence honest: the server marks them
/// offline as soon as the connection drops, and a heartbeat reports when GPS
/// is off even without new fixes. Outside work hours nothing is sent and the
/// live position is removed. GPS, permission and (Android) battery
/// optimization and notification permission in `presence` drive the `trackingAlerts` Cloud Function,
/// which warns the KAM, sales managers and GM.
///
/// Only the phone registered in `tracking_device/{uid}` sends anything
/// (see tracking_device.dart); on any other phone signed in to the same
/// account the tracker waits silently until that phone is chosen.
class LocationTracker {
  LocationTracker(this.uid, {this.onDutyChanged, this.onStandby});

  final String uid;

  /// Called when work hours start (true) or end (false), e.g. to change the
  /// Android service notification.
  final void Function(bool onDuty)? onDutyChanged;

  /// Called when another phone shares this account's location.
  final VoidCallback? onStandby;
  StreamSubscription<DatabaseEvent>? _deviceSub;
  String _deviceId = '';

  /// This phone is the one sharing the location.
  bool _active = false;
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<Position>? _positions;
  Timer? _heartbeat;
  Timer? _dutyCheck;
  DateTime? _lastSent;
  /// Still / walking / driving and since when in one place, sent with each fix.
  final _motion = MotionTracker();
  bool _connected = false;
  WorkHours _hours = WorkHours.defaults;
  Duration _interval = trackingInterval;

  /// Set for this person in App settings → Tracking schedules.
  TrackingSchedule _schedule = const TrackingSchedule.standard();

  /// Drivers keep the company car: tracked around the clock unless they have
  /// their own schedule (user decision 2026-10-20). Read from RTDB
  /// `roles/{uid}`, which the background service can read too.
  bool _driver = false;

  /// null until first checked.
  bool? _onDuty;

  DatabaseReference get _presence => FirebaseDatabase.instance.ref('presence/$uid');

  Future<void> start() async {
    _deviceId = await localDeviceId();
    _deviceSub = trackingDeviceRef(uid).onValue.listen((event) async {
      final owner = (event.snapshot.value as Map?)?['id'];
      if (owner == null) {
        // First phone of this account (or after a reset): it shares.
        await claimTracking(uid, _deviceId).catchError((_) {});
        return;
      }
      if (owner == _deviceId && !_active) {
        _active = true;
        await _startSharing();
      } else if (owner != _deviceId && _active) {
        _active = false;
        await _stopSharing();
        onStandby?.call();
      } else if (owner != _deviceId) {
        onStandby?.call();
      }
    });
  }

  Future<void> _startSharing() async {
    _subscriptions.add(FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) async {
      _connected = event.snapshot.value == true;
      if (!_connected) return;
      // Registered on the server: runs when the phone disconnects
      // (no signal, switched off, app killed).
      await _presence.onDisconnect().update({'online': false, 'lastSeen': ServerValue.timestamp});
      await _presence.update({'online': true, 'lastSeen': ServerValue.timestamp});
    }));
    // After a quick reconnect the server may notice the old, dropped
    // connection only later and run its onDisconnect, marking a connected
    // phone offline. Put it right while connected.
    _subscriptions.add(_presence.child('online').onValue.listen((event) {
      if (_connected && event.snapshot.value == false) {
        _presence.update({'online': true, 'lastSeen': ServerValue.timestamp}).ignore();
      }
    }));
    _subscriptions.add(FirebaseDatabase.instance.ref('roles/$uid').onValue.listen((event) {
      _driver = event.snapshot.value == 'driver';
      _applyDuty();
    }, onError: (_) {}));
    _subscriptions.add(workHoursRef.onValue.listen((event) {
      _hours = WorkHours.fromMap(event.snapshot.value);
      _applyDuty();
    }));
    _subscriptions.add(trackingScheduleRef(uid).onValue.listen((event) {
      _schedule = TrackingSchedule.fromMap(event.snapshot.value);
      _applyDuty();
    }, onError: (_) {}));
    _subscriptions.add(appSettingsRef.child(AppSetting.trackingIntervalSec.name).onValue.listen((event) {
      final interval = AppSettings.fromMap({AppSetting.trackingIntervalSec.name: event.snapshot.value}).trackingInterval;
      if (interval == _interval) return;
      _interval = interval;
      // Restarts the position stream with the new interval.
      if (_onDuty == true) {
        _onDuty = null;
        _applyDuty();
      }
    }, onError: (_) {}));
    // GPS switched on / off: report at once rather than at the next heartbeat.
    if (!kIsWeb) {
      _subscriptions.add(Geolocator.getServiceStatusStream().listen((_) => _beat(), onError: (_) {}));
    }
    _dutyCheck = Timer.periodic(const Duration(minutes: 1), (_) => _applyDuty());
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _beat());
    await _applyDuty();
  }

  /// Switches between sharing (work hours) and not sharing.
  Future<void> _applyDuty() async {
    final on = _schedule.isOn(DateTime.now(), _hours, driver: _driver);
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
      _motion.reset();
      await FirebaseDatabase.instance.ref('live_locations/$uid').remove();
    }
    await _presence.update({'onDuty': on});
    onDutyChanged?.call(on);
    // Fresh GPS / permission state for the start of the day.
    if (on) await _beat();
  }

  Future<void> stop() async {
    await _deviceSub?.cancel();
    _deviceSub = null;
    if (!_active) return; // another phone owns the presence
    _active = false;
    await _stopSharing();
    await _presence.update({'online': false, 'lastSeen': ServerValue.timestamp});
  }

  /// Stops sending without touching the presence (another phone may own it).
  Future<void> _stopSharing() async {
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
  }

  /// Status heartbeat; silent outside work hours (user decision): only the
  /// connection itself (online / offline) is kept by the server then.
  Future<void> _beat() async {
    if (_onDuty != true || !_active) return;
    var gpsOn = false;
    var permission = LocationPermission.denied;
    bool? batteryOptimized;
    bool? notifications;
    try {
      gpsOn = await Geolocator.isLocationServiceEnabled();
      permission = await Geolocator.checkPermission();
    } catch (_) {
      // Reported as GPS off / denied.
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        batteryOptimized = !await Permission.ignoreBatteryOptimizations.isGranted;
      } catch (_) {
        // Unknown: not reported.
      }
    }
    try {
      notifications = await Permission.notification.isGranted;
    } catch (_) {
      // Unknown: not reported.
    }
    await _presence.update({
      'lastSeen': ServerValue.timestamp,
      'notifications': ?notifications,
      'gpsOn': gpsOn,
      'permission': permission.name,
      'batteryOptimized': ?batteryOptimized,
    });
  }

  Future<void> _send(Position p) async {
    if (_onDuty != true || !_active) return;
    final now = DateTime.now();
    final motion = _motion.update(
      lat: p.latitude,
      lng: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      at: p.timestamp,
    );
    // The OS may deliver fixes more often than asked for; keep one per interval.
    if (_lastSent != null && now.difference(_lastSent!) < _interval * 0.75) return;
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
      'stillSince': motion.stillSince.millisecondsSinceEpoch,
      'motion': motion.motion.name,
      'updatedAt': ServerValue.timestamp,
    });
    // Route history per day, for the dashboard (distance, time in the field).
    final day = DateFormat('yyyy-MM-dd').format(now);
    await FirebaseDatabase.instance.ref('location_history/$uid/$day').push().set({
      ...point,
      't': ServerValue.timestamp,
      // Which phone sent it, to tell phones apart if two ever send.
      'd': _deviceId,
    });
    // Remembers long gaps (the phone paused the app) for the Home card.
    await noteLocationSent(now);
  }

  LocationSettings _settings() => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: _interval,
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
