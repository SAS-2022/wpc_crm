import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/home/stats.dart';

void main() {
  test('month range covers the whole month', () {
    final r = StatsRange.month(DateTime(2026, 2, 14));
    expect(r.start, DateTime(2026, 2, 1));
    expect(r.end, DateTime(2026, 2, 28));
    expect(r.days, 28);
    expect(r.months, ['2026-02']);
    expect(r.contains(DateTime(2026, 2, 28, 23, 59)), isTrue);
    expect(r.contains(DateTime(2026, 3, 1)), isFalse);
  });

  test('target is the monthly target for a full month and spread for part of one', () {
    expect(targetFor(80, StatsRange.month(DateTime(2026, 10))), closeTo(80, 0.001));
    // 10 of October's 31 days.
    expect(targetFor(62, StatsRange(DateTime(2026, 10, 1), DateTime(2026, 10, 10))), closeTo(20, 0.001));
    // Expected by the 15th of a 30-day month: half.
    expect(targetFor(80, StatsRange.month(DateTime(2026, 11)), until: DateTime(2026, 11, 15)), closeTo(40, 0.001));
    expect(targetFor(0, StatsRange.month(DateTime(2026, 11))), 0);
  });

  test('a range across two months uses each month\'s days', () {
    final r = StatsRange(DateTime(2026, 10, 31), DateTime(2026, 11, 1));
    expect(r.months, ['2026-10', '2026-11']);
    expect(targetFor(60, r), closeTo(60 / 31 + 60 / 30, 0.001));
  });

  test('pace', () {
    expect(paceOf(10, 10), Pace.onTrack);
    expect(paceOf(9, 10), Pace.slightlyBehind);
    expect(paceOf(5, 10), Pace.behind);
    expect(paceOf(0, 0), Pace.onTrack);
  });
}
