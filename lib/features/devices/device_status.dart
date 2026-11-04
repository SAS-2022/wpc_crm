import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_user.dart';
import '../../core/app_version.dart';
import '../../core/providers.dart';
import '../notifications/notifications.dart' show peopleUnder;
import '../tracking/device_health.dart' show restrictedBucket;
import '../tracking/live_data.dart' show Presence, locationReadIds, readsAllLocations, rtdbNodes;

// Phone status page (user request 2026-11-01): each employee's phone state —
// GPS, Wi-Fi / mobile data, permissions — as a grid for managers. Phones
// write RTDB `device_status/{uid}` {platform, app, maker, gps, location,
// precise, notifications, camera, batteryOptimized, backgroundRestricted,
// sleeping, network [wifi|mobile|ethernet|vpn|other], at}: the app when it is
// opened / resumed and every 5 min while open, the tracker with each
// heartbeat while it shares (2 min). Android-only keys are left out on iPhones.
// Phones can only tell which connection is in use: on Wi-Fi, whether mobile
// data is also switched on can't be read.

/// One check on the phone status card, in the order shown.
enum PhoneCheck { gps, location, precise, network, notifications, battery, background, camera }

enum CheckState { ok, problem, unknown }

class DeviceStatus {
  const DeviceStatus({
    required this.platform,
    this.app,
    this.maker,
    this.model,
    this.deviceName,
    this.os,
    this.gps,
    this.location,
    this.precise,
    this.notifications,
    this.camera,
    this.batteryOptimized,
    this.backgroundRestricted,
    this.sleeping,
    this.network,
    this.at,
  });

  final String platform;
  final String? app;
  final String? maker;

  /// Model code ("23021RAAEG"), the phone's own name ("Redmi Note 12") and
  /// system ("Android 15", "iOS 18.1"); builds from 2026-11-02 on.
  final String? model;
  final String? deviceName;
  final String? os;
  final bool? gps;

  /// Location permission: always | whileInUse | denied | deniedForever.
  final String? location;
  final bool? precise;
  final bool? notifications;
  final bool? camera;
  final bool? batteryOptimized;
  final bool? backgroundRestricted;
  final bool? sleeping;

  /// Connections in use; empty = no internet. null = not reported.
  final List<String>? network;
  final DateTime? at;

  bool get android => platform == 'android';

  /// "Redmi Note 12 · xiaomi 23021RAAEG · Android 15" (what is known).
  String? get phoneLabel {
    final parts = [
      ?deviceName,
      if (maker != null || model != null) [?maker, ?model].join(' '),
      ?os,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static DeviceStatus? fromMap(Object? v) {
    if (v is! Map) return null;
    bool? b(String k) => v[k] is bool ? v[k] as bool : null;
    String? s(String k) => v[k] is String && (v[k] as String).isNotEmpty ? v[k] as String : null;
    final net = v['network'];
    return DeviceStatus(
      platform: s('platform') ?? '',
      app: s('app'),
      maker: s('maker'),
      model: s('model'),
      deviceName: s('deviceName'),
      os: s('os'),
      gps: b('gps'),
      location: s('location'),
      precise: b('precise'),
      notifications: b('notifications'),
      camera: b('camera'),
      batteryOptimized: b('batteryOptimized'),
      backgroundRestricted: b('backgroundRestricted'),
      sleeping: b('sleeping'),
      // RTDB keeps an empty list as nothing: 'none' marks "no connection".
      network: net is List ? [for (final n in net) if (n != 'none') '$n'] : (net is Map ? [for (final n in net.values) if (n != 'none') '$n'] : null),
      at: v['at'] is num ? DateTime.fromMillisecondsSinceEpoch((v['at'] as num).toInt()) : null,
    );
  }

  /// The checks that apply to this phone (Android-only ones left out on iPhones).
  List<PhoneCheck> get checks => [
        for (final c in PhoneCheck.values)
          if (android || !const {PhoneCheck.battery, PhoneCheck.background, PhoneCheck.camera}.contains(c)) c,
      ];

  CheckState state(PhoneCheck c) {
    CheckState ok(bool? v) => v == null ? CheckState.unknown : (v ? CheckState.ok : CheckState.problem);
    return switch (c) {
      PhoneCheck.gps => ok(gps),
      PhoneCheck.location => location == null ? CheckState.unknown : ok(location == 'always'),
      PhoneCheck.precise => ok(precise),
      PhoneCheck.network => network == null ? CheckState.unknown : ok(network!.isNotEmpty),
      PhoneCheck.notifications => ok(notifications),
      PhoneCheck.battery => batteryOptimized == null ? CheckState.unknown : ok(!batteryOptimized!),
      PhoneCheck.background => backgroundRestricted == null && sleeping == null
          ? CheckState.unknown
          : ok(backgroundRestricted != true && sleeping != true),
      PhoneCheck.camera => ok(camera),
    };
  }

  /// Checks that need fixing. The camera is only needed for photos, so it
  /// isn't counted as a problem.
  List<PhoneCheck> get problems =>
      [for (final c in checks) if (c != PhoneCheck.camera && state(c) == CheckState.problem) c];
}

/// A phone that should share its location now (tracking or attendance
/// recording hours) and has sent nothing for this long has stopped
/// reporting. It sends every 30 s and a heartbeat every 2 min; the server's
/// wake ping goes out after 10 min.
const stoppedAfter = Duration(minutes: 15);

enum PhoneSignal {
  /// Sent something in the last [stoppedAfter].
  recent,

  /// Quiet for longer, but nothing is expected now (off duty, not tracked).
  quiet,

  /// Should share now and has been quiet for [stoppedAfter] or more.
  stopped,

  /// No phone has ever reported for this person.
  noPhone,
}

/// One person's phone on the Phone status page, from every sign the phone
/// sends (user 2026-11-02: almost everyone showed "No report yet", since
/// only the newest build writes `device_status`): its own report, else the
/// tracker's `presence` (GPS, permission, notifications, battery) and the
/// app version; last heard = the newest of those, the live position and the
/// last recorded route point.
class PhoneReport {
  const PhoneReport({
    required this.status,
    required this.lastHeard,
    required this.signal,
    required this.fromOldApp,
    this.shouldShare = false,
    this.quiet,
    this.lastPosition,
  });

  /// Should share now but no position came for [stoppedAfter]: why
  /// (2026-11-04). Also set while the phone itself still reports
  /// ([QuietReason.notRecording]).
  final QuietReason? quiet;

  /// Newest position (live or recorded today).
  final DateTime? lastPosition;

  /// Null when nothing about the phone's settings is known.
  final DeviceStatus? status;
  final DateTime? lastHeard;
  final PhoneSignal signal;

  /// [status] built from the tracker's presence (an app build before the
  /// phone status report): network, precise, camera, background unknown.
  final bool fromOldApp;

  /// The location should be shared / recorded now.
  final bool shouldShare;

  /// Not sending its location while it should (silent, or the phone
  /// reports but no positions come).
  bool get stopped => signal == PhoneSignal.stopped || quiet != null;

  /// Stopped reporting counts as a problem, before the settings.
  int get problemCount =>
      (stopped || (signal == PhoneSignal.noPhone && shouldShare) ? 1 : 0) + (status?.problems.length ?? 0);
}

PhoneReport phoneReport({
  required DeviceStatus? device,
  required Presence? presence,
  required DateTime? liveAt,
  required DateTime? recordedAt,
  required Map<String, InstalledVersion> versions,
  required bool shouldShare,
  required DateTime now,
}) {
  DateTime? latest(Iterable<DateTime?> times) =>
      times.nonNulls.fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  final lastHeard = latest([
    device?.at,
    presence?.lastSeen,
    liveAt,
    recordedAt,
    for (final v in versions.values) v.at,
  ]);
  var status = device;
  var old = false;
  if (status == null && presence != null) {
    old = true;
    final platform = versions.containsKey('android') || versions.isEmpty ? 'android' : versions.keys.first;
    status = DeviceStatus(
      platform: platform,
      app: versions[platform]?.label,
      gps: presence.gpsOn,
      location: presence.permission.isEmpty ? null : presence.permission,
      notifications: presence.notifications,
      batteryOptimized: platform == 'android' ? presence.batteryOptimized : null,
      at: presence.lastSeen,
    );
  }
  final signal = lastHeard == null && versions.isEmpty
      ? PhoneSignal.noPhone
      : lastHeard != null && now.difference(lastHeard) < stoppedAfter
          ? PhoneSignal.recent
          : shouldShare
              ? PhoneSignal.stopped
              : PhoneSignal.quiet;
  final lastPosition = latest([liveAt, recordedAt]);
  final quiet = shouldShare && signal != PhoneSignal.noPhone && (lastPosition == null || now.difference(lastPosition) >= stoppedAfter)
      ? quietReason(device: device, presence: presence, lastPosition: lastPosition, now: now)
      : null;
  return PhoneReport(
    status: status,
    lastHeard: lastHeard,
    signal: signal,
    fromOldApp: old,
    shouldShare: shouldShare,
    quiet: quiet,
    lastPosition: lastPosition,
  );
}

/// Why a phone that should share its location sent none lately
/// (2026-11-04, user: "Offline" didn't say what was really happening).
enum QuietReason {
  /// GPS / location services switched off on the phone.
  gpsOff,

  /// Location permission isn't "Allow all the time".
  noPermission,

  /// The phone still reports (the app opens) but sends no positions: the
  /// background recording isn't running (maker battery manager, autostart).
  notRecording,

  /// Nothing at all from the phone, and its last report had no internet.
  noInternet,

  /// Nothing at all from the phone: the app was closed by the phone
  /// (battery saving / autostart off / swiped away) or the phone is off.
  appClosed,
}

/// [device] the phone's last own report, [presence] the tracker's (tracked
/// roles only), [lastPosition] the newest position (live or recorded). Null
/// when the phone never reported anything.
QuietReason? quietReason({
  required DeviceStatus? device,
  required Presence? presence,
  required DateTime? lastPosition,
  required DateTime now,
}) {
  if (device == null && presence == null) return null;
  bool fresh(DateTime? t) => t != null && now.difference(t) < stoppedAfter;
  // The newest of the two reports decides the settings.
  final presenceNewer = presence != null && (device?.at == null || (presence.lastSeen?.isAfter(device!.at!) ?? false));
  final gps = presenceNewer ? presence.gpsOn : (device?.gps ?? presence?.gpsOn);
  final permission = presenceNewer
      ? (presence.permission.isEmpty ? device?.location : presence.permission)
      : (device?.location ?? (presence?.permission.isEmpty ?? true ? null : presence!.permission));
  if (gps == false) return QuietReason.gpsOff;
  if (permission != null && permission != 'always') return QuietReason.noPermission;
  // The phone answers (app open / heartbeat) yet no position came.
  if (fresh(device?.at) || (presence != null && presence.online && fresh(presence.lastSeen))) {
    if (!fresh(lastPosition)) return QuietReason.notRecording;
  }
  if (device?.network != null && device!.network!.isEmpty) return QuietReason.noInternet;
  return QuietReason.appClosed;
}

String? get _platform => kIsWeb
    ? null
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

const _device = MethodChannel('wpc/device');

/// Reads this phone's state and saves it on `device_status/{uid}`.
/// [background]: from the tracking service, where the app's own Android
/// channel (background restriction, maker) isn't there — those keys keep
/// their last value.
Future<void> reportDeviceStatus(String uid, {bool background = false}) async {
  final platform = _platform;
  if (platform == null) return;
  Future<T?> safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  final android = platform == 'android';
  final permission = await safe(Geolocator.checkPermission);
  final accuracy = permission == null || permission == LocationPermission.denied || permission == LocationPermission.deniedForever
      ? null
      : await safe(Geolocator.getLocationAccuracy);
  final net = await safe(() => Connectivity().checkConnectivity());
  final info = android && !background ? await safe(() => _device.invokeMapMethod<Object?, Object?>('info')) : null;
  final package = await safe(PackageInfo.fromPlatform);
  // iPhones have no app channel: the system version from Dart ("18.1").
  final iosVersion = platform == 'ios' ? RegExp(r'\d+(\.\d+)*').firstMatch(Platform.operatingSystemVersion)?.group(0) : null;
  final data = <String, Object?>{
    'platform': platform,
    'at': ServerValue.timestamp,
    'app': ?(package == null ? null : '${package.version} (${package.buildNumber})'),
    'gps': ?await safe(Geolocator.isLocationServiceEnabled),
    'location': ?permission?.name,
    'precise': ?(accuracy == null ? null : accuracy == LocationAccuracyStatus.precise),
    'notifications': ?await safe(() => Permission.notification.isGranted),
    'os': ?(iosVersion == null ? null : 'iOS $iosVersion'),
    if (android) ...{
      'camera': ?await safe(() => Permission.camera.isGranted),
      'batteryOptimized': ?(await safe(() => Permission.ignoreBatteryOptimizations.isGranted))?.let((v) => !v),
    },
    if (info != null) ...{
      'maker': ?(info['manufacturer'] as String?),
      'model': ?(info['model'] as String?),
      'deviceName': ?(info['deviceName'] as String?),
      'os': ?(info['os'] as String?),
      'backgroundRestricted': ?(info['backgroundRestricted'] as bool?),
      'sleeping': ?(info['standbyBucket'] as int?)?.let((v) => v >= restrictedBucket),
    },
    if (net != null)
      'network': [
        for (final r in net)
          if (r != ConnectivityResult.none) switch (r) {
            ConnectivityResult.wifi => 'wifi',
            ConnectivityResult.mobile => 'mobile',
            ConnectivityResult.ethernet => 'ethernet',
            ConnectivityResult.vpn => 'vpn',
            _ => 'other',
          },
      ].ifEmpty(const ['none']),
  };
  await safe(() => FirebaseDatabase.instance.ref('device_status/$uid').update(data));
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

extension on List<String> {
  List<String> ifEmpty(List<String> other) => isEmpty ? other : this;
}

/// Phones: reports the state when the app starts or comes back to the
/// front, and every 5 min while it is open. Listened in main.dart.
final deviceStatusReporterProvider = Provider<void>((ref) {
  if (_platform == null) return;
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return;
  void report() => reportDeviceStatus(uid).ignore();
  report();
  final timer = Timer.periodic(const Duration(minutes: 5), (_) => report());
  final lifecycle = AppLifecycleListener(onResume: report);
  // Wi-Fi ↔ mobile data ↔ offline: saved as it changes (sent once back online).
  final sub = Connectivity().onConnectivityChanged.listen((_) => report(), onError: (_) {});
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
    sub.cancel();
  });
});

/// Every phone's last reported state, by uid (managers, RTDB rules).
final deviceStatusesProvider = StreamProvider<Map<String, DeviceStatus>>((ref) {
  // The factory manager reads the whole list too; warehouse supervisors and
  // other department heads only the people under them (`location_viewers`).
  final ids = locationReadIds(ref, {...readsAllLocations, UserRole.factoryManager});
  return rtdbNodes('device_status', ids).map((nodes) => {
        for (final e in nodes.entries) e.key: ?DeviceStatus.fromMap(e.value),
      });
});

/// Who [me] sees on the phone status page: sales manager / GM everyone
/// active; others the people under them (a KAM their team, the logistics
/// manager drivers and logistics staff, the factory manager production).
List<AppUser> phoneStatusPeople(AppUser me, List<AppUser> users) {
  final active = users.where((u) => u.active && u.role != UserRole.unknown && u.role.value.isNotEmpty);
  if (me.role.isAdmin) return active.toList();
  final under = {for (final u in peopleUnder(me, users)) u.id};
  return active.where((u) => under.contains(u.id) || (me.role == UserRole.kam && u.kamId == me.id)).toList();
}
