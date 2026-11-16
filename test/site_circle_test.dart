import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/site_markers.dart';

void main() {
  test('site circle keeps its real radius up close and grows when zoomed out', () {
    // Riyadh, street level: 26 px ≈ 7 m, so the real 100 m stays.
    expect(siteCircleRadius(100, 24.7, 17), 100);
    // Country view: 26 px is kilometres.
    final far = siteCircleRadius(100, 24.7, 6);
    expect(far, greaterThan(10000));
    // Each zoom step out doubles it.
    expect(siteCircleRadius(100, 24.7, 5) / far, closeTo(2, 0.001));
  });
}
