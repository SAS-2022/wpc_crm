import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion.dart';

class LiveLocation {
  const LiveLocation({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.mocked,
    required this.updatedAt,
    this.fixAt,
    this.stillSince,
    this.motion,
  });

  /// Phone clock: when the fix was taken and since when the person has
  /// been in one place; [motion] null from app versions before 2026-10-19.
  final DateTime? fixAt;
  final DateTime? stillSince;
  final Motion? motion;

  final double lat;
  final double lng;
  final double? accuracy;
  final bool mocked;
  final DateTime? updatedAt;
}

class Presence {
  const Presence({
    required this.online,
    required this.lastSeen,
    required this.gpsOn,
    required this.permission,
    this.onDuty = true,
  });

  final bool online;

  /// false outside work hours, when no location is shared.
  final bool onDuty;
  final DateTime? lastSeen;
  final bool gpsOn;

  /// Location permission as last reported by the phone (e.g. "always", "denied").
  final String permission;
}

/// live = online with a fix in the last 5 minutes; stale = online but no
/// recent fix (GPS off, indoors); offDuty = online outside work hours (no
/// location shared); offline = phone disconnected.
enum LiveState { live, stale, offDuty, offline }

const _staleAfter = Duration(minutes: 5);

LiveState liveState(LiveLocation? location, Presence? presence, DateTime now) {
  if (presence == null || !presence.online) return LiveState.offline;
  if (!presence.onDuty) return LiveState.offDuty;
  final updated = location?.updatedAt;
  return updated != null && now.difference(updated) <= _staleAfter ? LiveState.live : LiveState.stale;
}

DateTime? _time(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

Map<String, Map<Object?, Object?>> _children(DataSnapshot s) => {
      if (s.value case final Map<Object?, Object?> map)
        for (final e in map.entries)
          if (e.value is Map<Object?, Object?>) '${e.key}': e.value as Map<Object?, Object?>,
    };

final liveLocationsProvider = StreamProvider<Map<String, LiveLocation>>((ref) =>
    FirebaseDatabase.instance.ref('live_locations').onValue.map((event) => {
          for (final MapEntry(:key, value: d) in _children(event.snapshot).entries)
            if (d['lat'] is num && d['lng'] is num)
              key: LiveLocation(
                lat: (d['lat'] as num).toDouble(),
                lng: (d['lng'] as num).toDouble(),
                accuracy: (d['accuracy'] as num?)?.toDouble(),
                mocked: d['mocked'] == true,
                updatedAt: _time(d['updatedAt']),
                fixAt: _time(d['fixAt']),
                stillSince: _time(d['stillSince']),
                motion: Motion.values.asNameMap()[d['motion']],
              ),
        }));

final presenceProvider = StreamProvider<Map<String, Presence>>((ref) =>
    FirebaseDatabase.instance.ref('presence').onValue.map((event) => {
          for (final MapEntry(:key, value: d) in _children(event.snapshot).entries)
            key: Presence(
              online: d['online'] == true,
              lastSeen: _time(d['lastSeen']),
              gpsOn: d['gpsOn'] != false,
              permission: '${d['permission'] ?? ''}',
              onDuty: d['onDuty'] != false,
            ),
        }));
