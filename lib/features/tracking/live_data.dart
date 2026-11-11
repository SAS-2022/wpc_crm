import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../notifications/notifications.dart' show peopleUnder;
import '../users/users_repository.dart';

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
    this.notifications,
    this.batteryOptimized,
  });

  /// Reported by the tracker (null on older builds / iPhones for the battery).
  final bool? notifications;
  final bool? batteryOptimized;

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

/// The roles whose RTDB rules let them read every person's location data.
const readsAllLocations = {UserRole.kam, UserRole.salesManager, UserRole.gm, UserRole.logisticsManager};

/// Everyone else (warehouse supervisors, department heads, other managers)
/// may read only the people under them — RTDB `location_viewers/{uid}`
/// (2026-11-04, kept by the `syncLocationViewers` function; drivers' warehouse
/// supervisor also via `driver_supervisors`): their ids. Null = read the
/// whole list. [all]: roles that may read the whole list of this node.
List<String>? locationReadIds(Ref ref, [Set<UserRole> all = readsAllLocations]) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  if (me.roles.any(all.contains)) return null;
  return [for (final u in peopleUnder(me, ref.watch(usersProvider).value ?? const <AppUser>[])) if (u.active) u.id]..sort();
}

/// The children of RTDB [path] by key: one listener on the whole list, or
/// one per id in [ids] (an id the rules refuse is left out, not an error).
Stream<Map<String, Map<Object?, Object?>>> rtdbNodes(String path, List<String>? ids) {
  final db = FirebaseDatabase.instance;
  if (ids == null) return db.ref(path).onValue.map((e) => _children(e.snapshot));
  if (ids.isEmpty) return Stream.value(const {});
  final latest = <String, Map<Object?, Object?>>{};
  final out = StreamController<Map<String, Map<Object?, Object?>>>();
  final subs = [
    for (final id in ids)
      db.ref('$path/$id').onValue.listen((e) {
        if (e.snapshot.value case final Map<Object?, Object?> v) {
          latest[id] = v;
        } else {
          latest.remove(id);
        }
        out.add(Map.of(latest));
      }, onError: (_) {
        latest.remove(id);
        out.add(Map.of(latest));
      }),
  ];
  out.onCancel = () {
    for (final s in subs) {
      s.cancel();
    }
  };
  return out.stream;
}

final liveLocationsProvider = StreamProvider<Map<String, LiveLocation>>((ref) =>
    rtdbNodes('live_locations', locationReadIds(ref)).map((nodes) => {
          for (final MapEntry(:key, value: d) in nodes.entries)
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
    rtdbNodes('presence', locationReadIds(ref)).map((nodes) => {
          for (final MapEntry(:key, value: d) in nodes.entries)
            key: Presence(
              online: d['online'] == true,
              lastSeen: _time(d['lastSeen']),
              gpsOn: d['gpsOn'] != false,
              permission: '${d['permission'] ?? ''}',
              onDuty: d['onDuty'] != false,
              notifications: d['notifications'] is bool ? d['notifications'] as bool : null,
              batteryOptimized: d['batteryOptimized'] is bool ? d['batteryOptimized'] as bool : null,
            ),
        }));

/// The last point of today's route history of people whose GPS is only
/// recorded ([AppUser.recordsGps]: no `live_locations`, no presence) — the
/// live map's "Production & logistics" section. Key = (day, uids joined by ',').
final recordedLocationsProvider = StreamProvider.family<Map<String, LiveLocation>, (String, String)>((ref, key) {
  final (day, ids) = key;
  if (ids.isEmpty) return Stream.value(const {});
  final latest = <String, LiveLocation>{};
  final out = StreamController<Map<String, LiveLocation>>();
  final subs = [
    for (final id in ids.split(','))
      FirebaseDatabase.instance.ref('location_history/$id/$day').orderByKey().limitToLast(1).onValue.listen((e) {
        final d = _children(e.snapshot).values.lastOrNull;
        if (d != null && d['lat'] is num && d['lng'] is num) {
          latest[id] = LiveLocation(
            lat: (d['lat'] as num).toDouble(),
            lng: (d['lng'] as num).toDouble(),
            accuracy: (d['accuracy'] as num?)?.toDouble(),
            mocked: d['mocked'] == true,
            updatedAt: _time(d['t']),
          );
        } else {
          latest.remove(id);
        }
        out.add(Map.of(latest));
      }, onError: (_) {
        latest.remove(id);
        out.add(Map.of(latest));
      }),
  ];
  out.onCancel = () {
    for (final s in subs) {
      s.cancel();
    }
  };
  return out.stream;
});

/// Recorded positions count as live while the last one is this fresh.
LiveState recordedState(LiveLocation? location, DateTime now) {
  final updated = location?.updatedAt;
  return updated != null && now.difference(updated) <= _staleAfter ? LiveState.live : LiveState.offline;
}
