import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phone settings that pause background tracking beyond the usual Android
// battery optimization (2026-10-19: a phone stopped sending for 2.5 h with
// every normal setting fine). Shown on the Home tracking card.

const _channel = MethodChannel('wpc/device');

/// Makers whose own battery managers pause background apps; each has a
/// setting the app can't read, so it's a checklist the person confirms.
enum PhoneBrand { xiaomi, samsung, huawei, oppo, vivo, oneplus, other }

PhoneBrand phoneBrand(String manufacturer) {
  final m = manufacturer.toLowerCase();
  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) return PhoneBrand.xiaomi;
  if (m.contains('samsung')) return PhoneBrand.samsung;
  if (m.contains('huawei') || m.contains('honor')) return PhoneBrand.huawei;
  if (m.contains('oppo') || m.contains('realme')) return PhoneBrand.oppo;
  if (m.contains('vivo')) return PhoneBrand.vivo;
  if (m.contains('oneplus')) return PhoneBrand.oneplus;
  return PhoneBrand.other;
}

/// Android's deepest standby bucket (UsageStatsManager.STANDBY_BUCKET_RESTRICTED).
const restrictedBucket = 45;

/// A stretch of work time when this phone sent no location.
typedef SendGap = ({DateTime from, DateTime to});

/// Gaps at least this long are reported to the person.
const gapToReport = Duration(minutes: 15);

const _lastSentKey = 'trackingLastSent';
const _gapKey = 'trackingGap';
const _brandDoneKey = 'phoneSetupDone';

/// The gap between the previous send and [now], when it is worth reporting:
/// at least [gapToReport] and on the same day (nights and days off aren't
/// gaps — nothing is sent outside work hours).
SendGap? gapBefore(DateTime? last, DateTime now) {
  if (last == null) return null;
  if (last.year != now.year || last.month != now.month || last.day != now.day) return null;
  return now.difference(last) >= gapToReport ? (from: last, to: now) : null;
}

/// Called by the tracker after each location it sends (any isolate): keeps
/// the time and remembers the latest long gap for the Home card.
Future<void> noteLocationSent(DateTime now) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastMs = prefs.getInt(_lastSentKey);
    final gap = gapBefore(lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs), now);
    if (gap != null) {
      await prefs.setString(_gapKey, '${gap.from.millisecondsSinceEpoch}-${gap.to.millisecondsSinceEpoch}');
      // Probably the phone's own battery manager: ask to check its settings again.
      await prefs.remove(_brandDoneKey);
    }
    await prefs.setInt(_lastSentKey, now.millisecondsSinceEpoch);
  } catch (e) {
    debugPrint('noteLocationSent: $e');
  }
}

class PhoneHealth {
  const PhoneHealth({
    required this.brand,
    required this.backgroundRestricted,
    required this.sleeping,
    required this.brandSetupDone,
    required this.gap,
    this.autostart,
    this.batteryOptimized = false,
  });

  final PhoneBrand brand;

  /// Battery usage set to "Restricted" for the app.
  final bool backgroundRestricted;

  /// Android put the app in its deepest sleep (standby bucket "restricted").
  final bool sleeping;

  /// The person confirmed the maker's auto-start / sleeping-apps settings.
  final bool brandSetupDone;

  /// Today's latest long stretch without sending, if any.
  final SendGap? gap;

  /// Xiaomi Autostart as read from the phone; null = can't be read (other
  /// makers, some MIUI versions): the person's confirmation counts then.
  final bool? autostart;

  /// Android battery optimization is on for the app (the one-tap "Allow
  /// running in the background" pop-up turns it off).
  final bool batteryOptimized;

  /// The maker checklist still to do. When Autostart can be read (Xiaomi)
  /// the phone decides: its battery saver "No restrictions" is Android's
  /// battery whitelist there ([batteryOptimized], checked on a Redmi with
  /// HyperOS 2, 2026-10-21), so nothing is left to confirm. Elsewhere the
  /// person confirms with "I've done this".
  bool get needsBrandSetup => brand != PhoneBrand.other && (autostart != null ? !autostart! : !brandSetupDone);
}

/// Android only (null elsewhere); refreshed when the Home card asks.
final phoneHealthProvider = FutureProvider<PhoneHealth?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  Map<Object?, Object?> info = const {};
  try {
    info = await _channel.invokeMapMethod<Object?, Object?>('info') ?? const {};
  } catch (_) {
    // Older Android: nothing to check.
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  SendGap? gap;
  final raw = prefs.getString(_gapKey)?.split('-');
  if (raw != null && raw.length == 2) {
    final from = DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw[0]) ?? 0);
    final to = DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw[1]) ?? 0);
    final now = DateTime.now();
    // Only today's.
    if (to.year == now.year && to.month == now.month && to.day == now.day) gap = (from: from, to: to);
  }
  return PhoneHealth(
    brand: phoneBrand(info['manufacturer'] as String? ?? ''),
    backgroundRestricted: info['backgroundRestricted'] == true,
    sleeping: (info['standbyBucket'] as int? ?? 0) >= restrictedBucket,
    brandSetupDone: prefs.getBool(_brandDoneKey) ?? false,
    gap: gap,
    autostart: info['autostart'] as bool?,
    batteryOptimized: !await Permission.ignoreBatteryOptimizations.isGranted.catchError((_) => true),
  );
});

/// Opens the maker's auto-start / background page (else the app settings).
Future<void> openBackgroundSettings() async {
  try {
    await _channel.invokeMethod<bool>('openBackgroundSettings');
  } catch (_) {}
}

/// The app's battery page (Xiaomi: Battery saver → "No restrictions").
Future<void> openBatterySettings() async {
  try {
    await _channel.invokeMethod<bool>('openBatterySettings');
  } catch (_) {}
}

Future<void> markBrandSetupDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_brandDoneKey, true);
}

Future<void> dismissSendGap() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_gapKey);
}
