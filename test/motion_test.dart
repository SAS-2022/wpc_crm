import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/motion.dart';

void main() {
  final t0 = DateTime(2026, 10, 19, 9);
  // ~0.00001° latitude ≈ 1.1 m.
  ({DateTime stillSince, Motion motion}) feed(MotionTracker m, int sec, double dLatMeters,
          {double speed = 0, double accuracy = 10}) =>
      m.update(lat: 24.7 + dLatMeters / 111320, lng: 46.7, accuracy: accuracy, speed: speed, at: t0.add(Duration(seconds: sec)));

  test('standing still with GPS jitter: still since the first fix', () {
    final m = MotionTracker();
    var r = feed(m, 0, 0);
    for (var i = 1; i <= 20; i++) {
      r = feed(m, i * 30, (i % 2) * 15.0); // ±15 m jitter, accuracy 10–20 m
    }
    expect(r.motion, Motion.still);
    expect(r.stillSince, t0);
  });

  test('driving: GPS speed above 11 km/h; the still point moves along', () {
    final m = MotionTracker();
    feed(m, 0, 0);
    var r = feed(m, 30, 400, speed: 13);
    r = feed(m, 60, 800, speed: 14);
    expect(r.motion, Motion.driving);
    expect(r.stillSince, t0.add(const Duration(seconds: 60)));
  });

  test('walking from distance / time when the phone gives no speed', () {
    final m = MotionTracker();
    feed(m, 0, 0);
    feed(m, 30, 40); // 1.3 m/s
    final r = feed(m, 60, 80);
    expect(r.motion, Motion.walking);
  });

  test('a rough fix far away doesn\'t end the stop', () {
    final m = MotionTracker();
    feed(m, 0, 0);
    feed(m, 30, 300, accuracy: 500);
    final r = feed(m, 60, 5);
    expect(r.stillSince, t0);
  });

  test('idle time: phone-clock stop + time since the server got it; only when still', () {
    final now = DateTime(2026, 10, 19, 10, 0);
    expect(
      idleFor(
        motion: Motion.still,
        stillSince: DateTime(2026, 10, 19, 9, 30), // phone clock, 2 min fast
        fixAt: DateTime(2026, 10, 19, 9, 52),
        updatedAt: DateTime(2026, 10, 19, 9, 50, 30),
        now: now,
      ),
      const Duration(minutes: 31, seconds: 30),
    );
    expect(idleFor(motion: Motion.driving, stillSince: now, fixAt: now, updatedAt: now, now: now), isNull);
    expect(idleFor(motion: null, stillSince: now, fixAt: now, updatedAt: now, now: now), isNull);
  });
}
