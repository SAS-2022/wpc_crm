import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/import/odoo_parser.dart';
import 'package:wpc_crm/features/import/plus_code.dart';

void main() {
  // The place URL a maps.app.goo.gl link (?g_st=ac) redirected to: no
  // coordinates, only a short Plus Code and the address (Al Malqa, Riyadh).
  const placeUrl = 'https://www.google.com/maps/place/RH8W%2B2QH+%D8%A3%D9%83%D8%AF%D8%A7%D9%84+Akdal%D8%8C+%D8%A7%D8%A8%D8%AD%D8%B1%D8%8C+%D8%A7%D9%84%D9%85%D9%84%D9%82%D8%A7%D8%8C+%D8%A7%D9%84%D8%B1%D9%8A%D8%A7%D8%B6+13525%E2%80%AD/data=!4m2!3m1!1s0x3e2ee5642a7e5791:0x477bbc4cc3be7184!18m1!1e1?utm_source=mstt_1&entry=gps&g_st=ac';

  test('a place link with only a Plus Code is read through the city in its address', () {
    final c = coordsFromUrl(placeUrl)!;
    expect(c.lat, closeTo(24.81506, 0.0001));
    expect(c.lng, closeTo(46.59698, 0.0001));
  });

  test('full codes decode without a city', () {
    final c = coordsFromPlusCode('7HP8RH8W+2QH')!;
    expect(c.lat, closeTo(24.81506, 0.0001));
    expect(c.lng, closeTo(46.59698, 0.0001));
  });

  test('short codes need a known city; other cities pick their own cell', () {
    expect(coordsFromPlusCode('RH8W+2QH'), isNull);
    final jeddah = coordsFromPlusCode('G4VC+QH Jeddah')!; // near the Corniche
    expect(jeddah.lat, closeTo(21.54, 0.5));
    expect(jeddah.lng, closeTo(39.17, 0.5));
  });

  test('city names are whole words; the last one named wins', () {
    expect(cityReference('the thumbnail'), isNull);
    expect(cityReference('حي الملقا، الرياض'), (24.7136, 46.6753));
    expect(cityReference('Riyadh road, Jeddah'), (21.5433, 39.1728));
  });

  test('links with coordinates still use them', () {
    expect(coordsFromUrl('https://www.google.com/maps/place/X/@24.1,46.1,17z/data=!3d24.5!4d46.7'), (lat: 24.5, lng: 46.7));
  });
}
