import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/tracking_log.dart';

TrackingEvent e(int hour, int minute, String type, [String value = '']) =>
    TrackingEvent(at: DateTime(2026, 10, 18, hour, minute), type: type, value: value);

void main() {
  test('problems are paired with the event that ended them', () {
    final log = trackingLog([
      e(13, 50, 'online'),
      e(10, 12, 'gpsOff'),
      e(13, 5, 'offline'),
      e(10, 40, 'gpsOn'),
    ]);
    expect([for (final l in log) l.event.type], ['gpsOff', 'gpsOn', 'offline', 'online']);
    expect(log[0].lasted, const Duration(minutes: 28));
    expect(log[2].lasted, const Duration(minutes: 45));
    expect(log[1].lasted, isNull);
  });

  test('a problem still going on has no duration', () {
    final log = trackingLog([e(9, 0, 'batteryOn')]);
    expect(log.single.lasted, isNull);
  });

  test('only reduced permissions count as problems', () {
    expect(e(9, 0, 'permission', 'whileInUse').isProblem, isTrue);
    expect(e(9, 0, 'permission', 'always').isProblem, isFalse);
    expect(e(9, 0, 'online').isProblem, isFalse);
  });

  test('notifications off is a problem ended by notifications on', () {
    final log = trackingLog([e(11, 0, 'notificationsOff'), e(11, 20, 'notificationsOn')]);
    expect(log.first.event.isProblem, isTrue);
    expect(log.first.lasted, const Duration(minutes: 20));
    expect(log.last.event.isProblem, isFalse);
  });
}
