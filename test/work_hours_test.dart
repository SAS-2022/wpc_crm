import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/live_data.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

void main() {
  // Saudi time is UTC+3, so 08:00 in Riyadh is 05:00 UTC.
  DateTime riyadh(int y, int m, int d, int h, [int min = 0]) => DateTime.utc(y, m, d, h - 3, min);
  const hours = WorkHours.defaults;

  test('sharing Saturday to Thursday 08:00–17:00 Saudi time, not on Friday', () {
    expect(hours.isOn(riyadh(2026, 10, 17, 8)), isTrue); // Saturday, start
    expect(hours.isOn(riyadh(2026, 10, 17, 7, 59)), isFalse);
    expect(hours.isOn(riyadh(2026, 10, 22, 16, 59)), isTrue); // Thursday
    expect(hours.isOn(riyadh(2026, 10, 22, 17)), isFalse); // end is exclusive
    expect(hours.isOn(riyadh(2026, 10, 16, 12)), isFalse); // Friday
  });

  test('uses Saudi time whatever the phone time zone is', () {
    // Thursday 23:30 UTC is already Friday 02:30 in Riyadh.
    expect(WorkHours.saudiTime(DateTime.utc(2026, 10, 15, 23, 30)).weekday, DateTime.friday);
  });

  test('settings round-trip and bad settings fall back to the defaults', () {
    final custom = WorkHours(days: {DateTime.sunday}, startMinute: 9 * 60, endMinute: 15 * 60);
    final back = WorkHours.fromMap(custom.toMap().map((k, v) => MapEntry<Object?, Object?>(k, v)));
    expect(back.days, {DateTime.sunday});
    expect(back.startMinute, 540);
    expect(back.endMinute, 900);
    expect(WorkHours.fromMap(null).days, hours.days);
    expect(WorkHours.fromMap({'days': [1], 'start': 600, 'end': 500}).startMinute, hours.startMinute);
  });

  test('online outside work hours shows as off duty', () {
    final now = DateTime(2026, 10, 16, 12);
    final p = Presence(online: true, lastSeen: now, gpsOn: true, permission: 'always', onDuty: false);
    expect(liveState(null, p, now), LiveState.offDuty);
  });
}
