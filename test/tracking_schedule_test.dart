import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/settings/app_settings.dart';
import 'package:wpc_crm/features/tracking/tracking_schedule.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

void main() {
  // Saudi time = UTC+3. 2026-10-21 is a Wednesday, 2026-10-23 a Friday.
  final wedNoon = DateTime.utc(2026, 10, 21, 9);
  final wedEvening = DateTime.utc(2026, 10, 21, 17); // 20:00 Saudi
  final friNoon = DateTime.utc(2026, 10, 23, 9);
  const company = WorkHours.defaults;

  group('TrackingSchedule', () {
    test('missing or invalid entry is standard', () {
      expect(TrackingSchedule.fromMap(null).mode, TrackingMode.standard);
      expect(TrackingSchedule.fromMap({'mode': 'own', 'days': [], 'start': 60, 'end': 120}).mode, TrackingMode.standard);
      expect(TrackingSchedule.fromMap({'mode': 'own', 'days': [3], 'start': 600, 'end': 500}).mode, TrackingMode.standard);
    });

    test('standard follows company hours, drivers all day', () {
      const s = TrackingSchedule.standard();
      expect(s.isOn(wedNoon, company, driver: false), isTrue);
      expect(s.isOn(wedEvening, company, driver: false), isFalse);
      expect(s.isOn(friNoon, company, driver: false), isFalse);
      expect(s.isOn(friNoon, company, driver: true), isTrue);
      expect(s.toMap(), isNull);
    });

    test('own hours replace company hours, also for drivers', () {
      final s = TrackingSchedule.fromMap({'mode': 'own', 'days': [3, 5], 'start': 14 * 60, 'end': 22 * 60});
      expect(s.mode, TrackingMode.own);
      expect(s.isOn(wedNoon, company, driver: true), isFalse);
      expect(s.isOn(wedEvening, company, driver: false), isTrue);
      expect(TrackingSchedule.fromMap(s.toMap()).hours, s.hours);
    });

    test('all day', () {
      final s = TrackingSchedule.fromMap({'mode': 'allDay'});
      expect(s.isOn(friNoon, company, driver: false), isTrue);
      expect(s.toMap(), {'mode': 'allDay'});
    });
  });

  group('AppSettings', () {
    test('defaults, valid and out-of-range values', () {
      final s = AppSettings.fromMap({'trackingIntervalSec': 60, 'visitRadiusM': 10, 'lateGraceMin': 'x'});
      expect(s[AppSetting.trackingIntervalSec], 60);
      expect(s.trackingInterval, const Duration(minutes: 1));
      expect(s[AppSetting.visitRadiusM], 300);
      expect(s[AppSetting.lateGraceMin], 15);
      expect(AppSettings.fromMap(null)[AppSetting.offlineAlertMin], 30);
    });
  });
}
