import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../attendance/attendance_rules.dart' as attendance;
import '../clients/given_items.dart' as given;
import '../visits/visit.dart' as visit;

/// One editable number of [AppSettings]: its key in RTDB `settings/app`,
/// default and allowed range.
enum AppSetting {
  /// How often a tracked phone sends its position (user decision 2026-10-18: 30 s).
  trackingIntervalSec(30, 15, 600),

  /// Offline this long during work time → `offlineAlerts` notifies.
  offlineAlertMin(30, 10, 240),

  /// Check-ins farther than this from the client are flagged.
  visitRadiusM(300, 50, 2000),

  /// Attendance check-ins up to this many minutes after the start aren't late.
  lateGraceMin(15, 0, 60),

  /// Catalogs / stands due within this many days show "due soon".
  givenDueSoonDays(14, 1, 90);

  const AppSetting(this.defaultValue, this.min, this.max);

  final int defaultValue;
  final int min;
  final int max;
}

/// Limits that used to be fixed in the code, edited by the GM / sales
/// manager in More → App settings (2026-10-21). Stored in RTDB
/// `settings/app` {key: number} so the Android background service and the
/// Cloud Functions read them too; a missing or invalid value is the default.
class AppSettings {
  const AppSettings(this.values);

  static const defaults = AppSettings({});

  final Map<AppSetting, int> values;

  int operator [](AppSetting s) => values[s] ?? s.defaultValue;

  factory AppSettings.fromMap(Object? value) {
    final map = value is Map ? value : const {};
    return AppSettings({
      for (final s in AppSetting.values)
        if (map[s.name] case final num v when v >= s.min && v <= s.max) s: v.toInt(),
    });
  }

  Duration get trackingInterval => Duration(seconds: this[AppSetting.trackingIntervalSec]);

  /// Copies the values used by plain functions (visit flags, catalog status,
  /// lateness) into their globals.
  void apply() {
    visit.visitRadiusMeters = this[AppSetting.visitRadiusM].toDouble();
    given.givenDueSoonDays = this[AppSetting.givenDueSoonDays];
    attendance.lateGraceMin = this[AppSetting.lateGraceMin];
  }
}

DatabaseReference get appSettingsRef => FirebaseDatabase.instance.ref('settings/app');

/// Only readable once signed in with a role; defaults until then.
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(AppSettings.defaults);
  return appSettingsRef.onValue
      .map((e) => AppSettings.fromMap(e.snapshot.value))
      .handleError((Object _) {});
});
