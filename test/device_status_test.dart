import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/city_areas.dart';
import 'package:wpc_crm/core/app_version.dart';
import 'package:wpc_crm/features/devices/device_status.dart';
import 'package:wpc_crm/features/tracking/live_data.dart';

void main() {
  group('DeviceStatus', () {
    test('reads an Android report and finds the problems', () {
      final s = DeviceStatus.fromMap({
        'platform': 'android',
        'gps': true,
        'location': 'whileInUse',
        'precise': true,
        'notifications': false,
        'camera': false,
        'batteryOptimized': true,
        'backgroundRestricted': false,
        'sleeping': false,
        'network': ['wifi', 'mobile'],
        'at': 1000,
      })!;
      expect(s.network, ['wifi', 'mobile']);
      expect(s.at, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(s.state(PhoneCheck.gps), CheckState.ok);
      expect(s.state(PhoneCheck.background), CheckState.ok);
      // Camera off is shown but not counted.
      expect(s.state(PhoneCheck.camera), CheckState.problem);
      expect(s.problems, [PhoneCheck.location, PhoneCheck.notifications, PhoneCheck.battery]);
    });

    test('"none" = no internet; iPhones have no Android-only checks', () {
      final s = DeviceStatus.fromMap({'platform': 'ios', 'network': ['none'], 'location': 'always'})!;
      expect(s.network, isEmpty);
      expect(s.state(PhoneCheck.network), CheckState.problem);
      expect(s.state(PhoneCheck.location), CheckState.ok);
      expect(s.state(PhoneCheck.gps), CheckState.unknown);
      expect(s.checks, isNot(contains(PhoneCheck.battery)));
      expect(s.checks, isNot(contains(PhoneCheck.camera)));
      expect(s.problems, [PhoneCheck.network]);
    });

    test('sleeping counts as a background problem; not a map = null', () {
      expect(DeviceStatus.fromMap({'platform': 'android', 'sleeping': true})!.state(PhoneCheck.background),
          CheckState.problem);
      expect(DeviceStatus.fromMap('x'), isNull);
    });
  });

  test('Saudi regions', () {
    // Central: Riyadh, Buraidah, Hail, Majmaah.
    for (final (lat, lng) in [(24.7136, 46.6753), (26.3592, 43.9818), (27.5114, 41.7208), (25.9035, 45.3470)]) {
      expect(SaudiRegion.of(lat, lng), SaudiRegion.central, reason: '$lat,$lng');
    }
    // Western: Jeddah, Makkah, Madinah, Taif, Tabuk, Abha, Jazan, Najran.
    for (final (lat, lng) in [
      (21.5433, 39.1728), (21.3891, 39.8579), (24.5247, 39.5692), (21.2703, 40.4158),
      (28.3835, 36.5662), (18.2164, 42.5053), (16.8892, 42.5511), (17.5656, 44.2289),
    ]) {
      expect(SaudiRegion.of(lat, lng), SaudiRegion.western, reason: '$lat,$lng');
    }
    // Eastern: Dammam, Khobar, Jubail, Al Ahsa (Hofuf), Hafar Al Batin.
    for (final (lat, lng) in [(26.4207, 50.0888), (26.2172, 50.1971), (27.0046, 49.6460), (25.3830, 49.5860), (28.4328, 45.9708)]) {
      expect(SaudiRegion.of(lat, lng), SaudiRegion.eastern, reason: '$lat,$lng');
    }
    expect(SaudiRegion.central.contains(21.5433, 39.1728), isFalse);
    // Outside Saudi Arabia (Cairo).
    expect(SaudiRegion.of(30.0444, 31.2357), isNull);
  });

  group('phoneReport', () {
    final now = DateTime(2026, 11, 2, 11);
    final versions = {'android': InstalledVersion(version: '1.0.16', build: 21, at: DateTime(2026, 10, 20))};
    Presence presence(DateTime lastSeen, {bool online = true}) => Presence(
          online: online,
          lastSeen: lastSeen,
          gpsOn: false,
          permission: 'always',
          notifications: true,
          batteryOptimized: true,
        );

    test('older app: settings from the tracker presence', () {
      final r = phoneReport(
        device: null,
        presence: presence(now.subtract(const Duration(minutes: 2))),
        liveAt: null,
        recordedAt: null,
        versions: versions,
        shouldShare: true,
        now: now,
      );
      expect(r.fromOldApp, isTrue);
      expect(r.signal, PhoneSignal.recent);
      expect(r.status!.app, '1.0.16 (21)');
      expect(r.status!.problems, [PhoneCheck.gps, PhoneCheck.battery]);
      expect(r.status!.state(PhoneCheck.network), CheckState.unknown);
    });

    test('quiet while it should share = stopped; off duty = only quiet', () {
      final old = presence(now.subtract(const Duration(minutes: 40)), online: false);
      PhoneReport args(Presence p, bool share, DateTime? live) => phoneReport(
            device: null,
            presence: p,
            liveAt: live,
            recordedAt: null,
            versions: versions,
            shouldShare: share,
            now: now,
          );
      expect(args(old, true, null).signal, PhoneSignal.stopped);
      expect(args(old, true, null).problemCount, 3);
      expect(args(old, true, null).lastHeard, now.subtract(const Duration(minutes: 40)));
      expect(args(old, false, null).signal, PhoneSignal.quiet);
      // A fresh live position counts as a sign.
      expect(args(old, true, now.subtract(const Duration(minutes: 1))).signal, PhoneSignal.recent);
    });

    test('office staff: the last recorded point; no phone ever', () {
      final r = phoneReport(
        device: null,
        presence: null,
        liveAt: null,
        recordedAt: now.subtract(const Duration(minutes: 5)),
        versions: const {},
        shouldShare: true,
        now: now,
      );
      expect(r.signal, PhoneSignal.recent);
      expect(r.status, isNull);
      final none = phoneReport(
        device: null,
        presence: null,
        liveAt: null,
        recordedAt: null,
        versions: const {},
        shouldShare: true,
        now: now,
      );
      expect(none.signal, PhoneSignal.noPhone);
      expect(none.problemCount, 1);
    });
  });

  test('phone label from the report', () {
    final s = DeviceStatus.fromMap({
      'platform': 'android',
      'maker': 'xiaomi',
      'model': '23021RAAEG',
      'deviceName': 'Redmi Note 12',
      'os': 'Android 15',
    })!;
    expect(s.phoneLabel, 'Redmi Note 12 · xiaomi 23021RAAEG · Android 15');
    expect(DeviceStatus.fromMap({'platform': 'ios', 'os': 'iOS 18.1'})!.phoneLabel, 'iOS 18.1');
  });

  group('quietReason', () {
    final now = DateTime(2026, 11, 4, 10);
    DeviceStatus dev({bool gps = true, String location = 'always', List<String>? network = const ['wifi'], int ago = 1}) =>
        DeviceStatus(platform: 'android', gps: gps, location: location, network: network, at: now.subtract(Duration(minutes: ago)));
    QuietReason? r(DeviceStatus? d, {Presence? p, int? pointAgo}) => quietReason(
          device: d,
          presence: p,
          lastPosition: pointAgo == null ? null : now.subtract(Duration(minutes: pointAgo)),
          now: now,
        );

    test('nothing ever reported', () => expect(r(null), isNull));
    test('GPS off wins', () => expect(r(dev(gps: false, ago: 120)), QuietReason.gpsOff));
    test('permission not always', () => expect(r(dev(location: 'whileInUse')), QuietReason.noPermission));
    test('phone reports but no positions', () {
      expect(r(dev(ago: 3), pointAgo: 120), QuietReason.notRecording);
      expect(r(dev(ago: 3)), QuietReason.notRecording);
    });
    test('phone silent', () {
      expect(r(dev(ago: 115), pointAgo: 113), QuietReason.appClosed);
      expect(r(dev(ago: 115, network: const []), pointAgo: 113), QuietReason.noInternet);
    });
    test('newer presence decides GPS', () {
      final p = Presence(online: true, lastSeen: now.subtract(const Duration(minutes: 1)), gpsOn: false, permission: 'always');
      expect(r(dev(ago: 60), p: p, pointAgo: 30), QuietReason.gpsOff);
      final on = Presence(online: true, lastSeen: now.subtract(const Duration(minutes: 1)), gpsOn: true, permission: 'always');
      expect(r(null, p: on, pointAgo: 30), QuietReason.notRecording);
      final off = Presence(online: false, lastSeen: now.subtract(const Duration(minutes: 60)), gpsOn: true, permission: 'always');
      expect(r(null, p: off, pointAgo: 60), QuietReason.appClosed);
    });
  });
}
