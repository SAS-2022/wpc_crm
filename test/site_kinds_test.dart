import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/map_controls.dart';
import 'package:wpc_crm/features/attendance/work_sites.dart';

void main() {
  test('radius steps include 25 / 50 / 75 and snap old values', () {
    expect(siteRadiusSteps.take(4), [25.0, 50.0, 75.0, 100.0]);
    expect(siteRadiusSteps[siteRadiusStep(25)], 25);
    expect(siteRadiusSteps[siteRadiusStep(120)], 100);
    expect(siteRadiusSteps[siteRadiusStep(500)], 500);
  });

  test('site kind falls back to office', () {
    expect(SiteKind.fromValue('warehouse'), SiteKind.warehouse);
    expect(SiteKind.fromValue(null), SiteKind.office);
    expect(SiteKind.fromValue('nope'), SiteKind.office);
  });

  test('pins shrink when zoomed out', () {
    expect(markerScaleForZoom(15), 1.0);
    expect(markerScaleForZoom(12), 0.8);
    expect(markerScaleForZoom(10), 0.62);
    expect(markerScaleForZoom(6), 0.48);
  });
}
