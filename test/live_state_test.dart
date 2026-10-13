import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/live_data.dart';

void main() {
  final now = DateTime(2026, 10, 12, 10);
  LiveLocation at(DateTime t) => LiveLocation(lat: 1, lng: 1, accuracy: 10, mocked: false, updatedAt: t);
  Presence presence({required bool online}) =>
      Presence(online: online, lastSeen: now, gpsOn: true, permission: 'always');

  test('live only when online with a fix in the last 5 minutes', () {
    expect(liveState(at(now.subtract(const Duration(minutes: 2))), presence(online: true), now), LiveState.live);
    expect(liveState(at(now.subtract(const Duration(minutes: 9))), presence(online: true), now), LiveState.stale);
    expect(liveState(null, presence(online: true), now), LiveState.stale);
  });

  test('offline wins over a recent fix, and no presence means offline', () {
    expect(liveState(at(now), presence(online: false), now), LiveState.offline);
    expect(liveState(at(now), null, now), LiveState.offline);
  });
}
