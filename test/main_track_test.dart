import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/reports/report.dart';

RoutePoint p(int minute, double lat, double lng) =>
    RoutePoint(lat: lat, lng: lng, t: DateTime(2026, 10, 17, 8).add(Duration(minutes: minute)));

void main() {
  test('a second phone in another city is dropped from the day', () {
    final dammam = [for (var m = 0; m < 600; m += 2) p(m, 26.43 + m * 0.00001, 50.04)];
    // Another phone signed in to the same account in Riyadh, 10:56–12:51.
    final riyadh = [for (var m = 176; m < 291; m += 4) p(m + 1, 24.71, 46.68)];
    final kept = mainTrack([...dammam, ...riyadh]);
    expect(kept.length, dammam.length);
    expect(kept.every((x) => x.lng > 48), isTrue);
  });

  test('a real drive between cities stays (120 km/h)', () {
    // Riyadh → Dammam, ~400 km in 3.5 h, a point every 2 minutes.
    final drive = [for (var m = 0; m <= 210; m += 2) p(m, 24.71 + (26.43 - 24.71) * m / 210, 46.68 + (50.04 - 46.68) * m / 210)];
    expect(mainTrack(drive).length, drive.length);
  });

  test('a single GPS glitch far away is dropped', () {
    final day = [for (var m = 0; m < 120; m += 2) p(m, 24.70, 46.70)];
    final kept = mainTrack([...day, p(61, 21.5, 39.2)]);
    expect(kept.length, day.length);
  });

  test('a phone that takes over later in the day elsewhere is kept', () {
    final morning = [for (var m = 0; m < 120; m += 2) p(m, 24.70, 46.70)];
    final evening = [for (var m = 600; m < 640; m += 2) p(m, 26.43, 50.04)]; // 400 km, 8 h later
    expect(mainTrack([...morning, ...evening]).length, morning.length + evening.length);
  });
}
