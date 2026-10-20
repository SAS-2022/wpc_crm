import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/reports/routing_pace.dart';

DateTime _t(int h, [int m = 0]) => DateTime(2026, 10, 20, h, m);

DayTimeline _day(String uid, String day, {required List<(int, int, int, int)> stays, int driving = 60, double km = 30, int lunch = 0, int office = 0}) {
  final s = [
    for (final (h1, m1, h2, m2) in stays) ClientStay(clientId: 'c', from: _t(h1, m1), to: _t(h2, m2)),
  ];
  return DayTimeline(
    uid: uid,
    day: day,
    minutes: {for (final k in TimeKind.values) k: 0},
    drivingKm: km,
    clientStays: s,
    stops: const [],
    firstClientAt: s.first.from,
    lastClientAt: s.last.to,
    between: {
      for (final k in TimeKind.values) k: 0,
      TimeKind.driving: driving,
      TimeKind.lunch: lunch,
      TimeKind.office: office,
    },
    betweenDrivingKm: km,
    isFinal: true,
  );
}

void main() {
  test('a person: average visit length, speed and road factor', () {
    final p = personPace('a', [
      _day('a', '2026-10-19', stays: [(9, 0, 9, 30), (10, 30, 11, 10)], driving: 60, km: 30),
      _day('a', '2026-10-20', stays: [(9, 0, 9, 20), (10, 0, 10, 30)], driving: 30, km: 15),
    ], {'2026-10-19': 20, '2026-10-20': 10});
    expect(p.days, 2);
    expect(p.visitMinutes, closeTo((30 + 40 + 20 + 30) / 4, 0.01));
    expect(p.speedKmh, closeTo(45 / 1.5, 0.01)); // 45 km in 90 min
    expect(p.roadFactor, closeTo(45 / 30, 0.01));
  });

  test('team: the median of the people, fixed guesses where nobody has data', () {
    const a = PersonPace(uid: 'a', days: 5, visitMinutes: 20, speedKmh: 25);
    const b = PersonPace(uid: 'b', days: 5, visitMinutes: 40, speedKmh: 35);
    const c = PersonPace(uid: 'c', days: 5, visitMinutes: 90, speedKmh: 30); // a slow one doesn't pull the median far
    const d = PersonPace(uid: 'd', days: 1, visitMinutes: 500); // too few days
    final t = teamPace([a, b, c, d]);
    expect(t.visitMinutes, 40);
    expect(t.speedKmh, 30);
    expect(t.roadFactor, TeamPace.defaults.roadFactor);
    expect(t.measured, {'visit', 'speed'});
    expect(t.people, 3);
    expect(median([1, 2, 3, 4]), 2.5);
  });

  test('10 visits with 30 km between them at the team pace', () {
    const t = TeamPace(visitMinutes: 30, speedKmh: 30, roadFactor: 1.5, people: 3);
    // 10 × 30 min + 30 km × 1.5 = 45 km at 30 km/h = 90 min → 6 h 30.
    expect(t.estimate(10, 30), const Duration(hours: 6, minutes: 30));
  });

  test('a day: took = first arrival to last departure minus lunch and office', () {
    const pace = TeamPace(visitMinutes: 30, speedKmh: 30, roadFactor: 1.0, people: 3);
    final visits = [
      (at: _t(9, 5), place: (24.70, 46.60)),
      (at: _t(14, 5), place: (24.70, 46.70)), // ~10 km east
    ];
    final timeline = _day('a', '2026-10-20', stays: [(9, 0, 9, 40), (14, 0, 14, 30)], lunch: 60, office: 90);
    final e = paceEfficiency(visits, pace: pace, timeline: timeline)!;
    expect(e.measured, isTrue);
    expect(e.took, const Duration(hours: 3)); // 9:00–14:30 = 5 h 30 − 2 h 30
    expect(e.needed.inMinutes, inInclusiveRange(78, 82)); // 2 × 30 + ~10 km at 30 km/h
    final noGps = paceEfficiency(visits, pace: pace)!;
    expect(noGps.measured, isFalse);
    expect(noGps.took, const Duration(hours: 5, minutes: 30)); // 9:05–14:05 + one visit
  });
}
