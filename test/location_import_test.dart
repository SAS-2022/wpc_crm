import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/import/import_service.dart';
import 'package:wpc_crm/features/import/location_import.dart';

Client client(String id, String name, {String vat = '', double? lat, List<String> aliases = const []}) => Client(
      id: id, vat: vat, nameKey: Client.normalizeName(name), name: name, aliases: aliases,
      phone: '', mobile: '', address: '', city: '', tags: '', odooSalesperson: '',
      googlePin: '', lat: lat, lng: lat, assignedTo: null, category: 'B', lastVisitAt: null,
    );

void main() {
  test('reads links, plain coordinates and lat/lng columns', () {
    final rows = parseLocationTable([
      ['Name', 'Location', 'Latitude', 'Longitude'],
      ['A', 'https://maps.google.com/?q=24.1,46.1', '', ''],
      ['B', '24.2, 46.2', '', ''],
      ['C', '', '24.3', '46.3'],
      ['D', 'https://maps.app.goo.gl/x', '', ''],
    ]);
    expect(rows.map((r) => r.coords), [(lat: 24.1, lng: 46.1), (lat: 24.2, lng: 46.2), (lat: 24.3, lng: 46.3), null]);
    expect(rows.last.link, 'https://maps.app.goo.gl/x');
  });

  test('reads Odoo pivot exports: salesperson header, indented names', () {
    final rows = parseLocationTable([
      ['          Eddy Abi Khalil @ Sales', 'AREA', 'LOCATION'],
      ['               Client One', 'Olaya', 'https://maps.google.com/?q=24.1,46.1'],
    ]);
    expect(rows.single.name, 'Client One');
    expect(rows.single.coords, (lat: 24.1, lng: 46.1));
  });

  test('pivot rows keep area and salesperson; unmatched rows become new clients once', () {
    final rows = parseLocationTable([
      ['Sami Mansour @ Sales', 'AREA ', 'LOCATION'],
      [' Known', 'Shifa', 'https://maps.google.com/?q=24.1,46.1'],
      [' New One', 'Faisaliah', 'https://maps.app.goo.gl/x'],
      [' New One', 'Faisaliah', ''],
      [' No Pin', '_', 'no location yet'],
    ]);
    expect(rows.first.name, 'Known');
    expect(rows.first.area, 'Shifa');
    expect(rows.first.salesperson, 'Sami Mansour @ Sales');
    expect(rows.last.area, '');
    expect(rows.last.note, 'no location yet');
    expect(rows.first.note, '');

    final plan = buildLocationPlan(
      rows: rows,
      clients: [client('1', 'Known')],
      resolvedLinks: {'https://maps.app.goo.gl/x': (lat: 24.5, lng: 46.5)},
    );
    expect(plan.updates.single.client.id, '1');
    expect(plan.newClients.map((n) => n.row.name), ['New One', 'No Pin']);
    expect(plan.newClients.map((n) => n.coords), [(lat: 24.5, lng: 46.5), null]);
  });

  test('rejects sheets without a name and a location column', () {
    expect(() => parseLocationTable([['Foo', 'Bar']]), throwsA(isA<LocationParseException>()));
  });

  test('matches by VAT, name or merged name and reports the rest', () {
    final rows = parseLocationTable([
      ['Name', 'Tax ID', 'Location'],
      ['Whatever', '300', '24.1, 46.1'],
      ['  beta  co ', '', '24.2, 46.2'],
      ['Old Branch', '', '24.3, 46.3'],
      ['Twin', '', '24.4, 46.4'],
      ['Nobody', '', '24.5, 46.5'],
      ['Gamma', '', 'https://maps.app.goo.gl/x'],
      ['Has', '', '1.0, 1.0'],
    ]);
    final plan = buildLocationPlan(
      rows: rows,
      clients: [
        client('a', 'Alpha', vat: '300'),
        client('b', 'Beta Co'),
        client('c', 'Main', aliases: ['Old Branch']),
        client('t1', 'Twin'),
        client('t2', 'Twin'),
        client('g', 'Gamma'),
        client('h', 'Has', lat: 1.0),
      ],
      resolvedLinks: const {},
    );
    expect(plan.updates.map((u) => u.client.id), ['a', 'b', 'c']);
    expect(plan.ambiguous.single.name, 'Twin');
    expect(plan.notFound.single.name, 'Nobody');
    expect(plan.unreadable.single.name, 'Gamma');
    expect(plan.unchanged, 1);
  });

  test('pasted text: plain coordinates and full links need no network', () async {
    expect(await coordsFromPastedText(' 24.630049, 46.807279 '), (lat: 24.630049, lng: 46.807279));
    expect(await coordsFromPastedText('Shop https://maps.google.com/?q=24.63,46.80&entry=gps'), (lat: 24.63, lng: 46.8));
    expect(await coordsFromPastedText('hello'), isNull);
  });
}
