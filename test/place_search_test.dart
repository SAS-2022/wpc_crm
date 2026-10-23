import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/place_search.dart';

void main() {
  test('parses Nominatim results with their area', () {
    final places = parsePlaces('''[
      {"display_name": "Al Salam, Riyadh, Saudi Arabia", "lat": "24.6551", "lon": "46.7926",
       "boundingbox": ["24.6400", "24.6700", "46.7800", "46.8100"]},
      {"display_name": "Somewhere", "lat": "21.5", "lon": "39.2"},
      {"display_name": "No point"}
    ]''');
    expect(places.length, 2);
    expect(places.first.name, 'Al Salam, Riyadh, Saudi Arabia');
    expect(places.first.lat, closeTo(24.6551, 1e-6));
    expect(places.first.bounds, (24.64, 46.78, 24.67, 46.81));
    expect(places[1].bounds, isNull);
    expect(parsePlaces('{"error": "x"}'), isEmpty);
  });

  test('zoom that shows an area', () {
    // Salam District, Riyadh (~1 km): street level.
    final district = zoomForBounds((24.6169521, 46.7058312, 24.6264164, 46.7111607), 400, 500);
    expect(district, inInclusiveRange(15, 17));
    // Riyadh city (~35 km): city level, further out.
    final city = zoomForBounds((24.4789160, 46.5560104, 24.7989160, 46.8760104), 400, 500);
    expect(city, inInclusiveRange(10, 11.5));
    expect(city, lessThan(district));
    // A point-sized box doesn't go past 17; a huge region not below 5.
    expect(zoomForBounds((24.6, 46.7, 24.6, 46.7), 400, 500), 17);
    expect(zoomForBounds((-80, -170, 80, 170), 400, 500), 5);
  });
}
