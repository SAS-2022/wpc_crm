import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/import/import_plan.dart';
import 'package:wpc_crm/features/import/odoo_parser.dart';

const header = ['Complete Name', 'Tax ID', 'Google Pin', 'Salesperson', 'City'];

Client existingClient({String id = 'c1', String vat = '', required String name, String pin = '', double? lat, String? assignedTo}) =>
    Client(
      id: id, vat: vat, nameKey: Client.normalizeName(name), name: name, aliases: const [],
      phone: '', mobile: '', address: '', city: '', tags: '', odooSalesperson: '',
      googlePin: pin, lat: lat, lng: lat, assignedTo: assignedTo, category: 'B', lastVisitAt: null,
    );

ImportPlan plan(List<List<String>> rows, {List<Client> existing = const [], Map<String, Coords> resolved = const {}}) =>
    buildPlan(
      rows: parseOdooTable([header, ...rows]),
      existing: existing,
      resolvedPins: resolved,
      salespersonToUid: {'sami @ sales': 'u1'},
    );

void main() {
  group('coordsFromUrl', () {
    test('reads the formats found in the Odoo export', () {
      expect(coordsFromUrl('https://maps.google.com/?q=24.529240,46.709270'), (lat: 24.52924, lng: 46.70927));
      expect(coordsFromUrl('https://maps.google.com/maps?q=24.5264%2C46.7085&z=17&hl=en'), (lat: 24.5264, lng: 46.7085));
      expect(coordsFromUrl('https://www.google.com/maps/search/?api=1&query=24.6045,46.8270'), (lat: 24.6045, lng: 46.827));
      expect(coordsFromUrl('https://maps.google.com/maps/search/Riyadh/@24.8287,46.6600,17z'), (lat: 24.8287, lng: 46.66));
    });

    test('prefers the place over the viewport', () {
      expect(
        coordsFromUrl('https://www.google.com/maps/place/X/@24.66,46.82,11z/data=!3d24.659!4d46.826'),
        (lat: 24.659, lng: 46.826),
      );
    });

    test('short links have no coordinates', () {
      expect(coordsFromUrl('https://maps.app.goo.gl/RkjxvZr1zQUdrz7J6'), isNull);
      expect(isShortLink('https://maps.app.goo.gl/RkjxvZr1zQUdrz7J6'), isTrue);
      expect(isShortLink('https://goo.gl/maps/EeBkwXxm9Fr8dV8E9?g_st=awb'), isTrue);
      expect(isShortLink('https://maps.google.com/?q=1.0,2.0'), isFalse);
    });

    test('extracts a link from text around it', () {
      expect(extractUrl('مصنع https://maps.google.com/?q=25.6,45.7'), 'https://maps.google.com/?q=25.6,45.7');
      expect(extractUrl('transfer-https://maps.google.com/?q=1.5,2.5'), 'https://maps.google.com/?q=1.5,2.5');
    });
  });

  group('buildPlan', () {
    test('creates every client and flags the ones without a location', () {
      final p = plan([
        ['A Co', '300', 'https://maps.google.com/?q=24.1,46.1', 'Sami @ Sales', 'Riyadh'],
        ['B Co', '', '', '', ''],
        ['C Co', '', 'https://maps.app.goo.gl/x', '', ''],
      ]);
      expect(p.creates.map((w) => w.name), ['A Co', 'B Co', 'C Co']);
      expect(p.creates.first.data['assignedTo'], 'u1');
      expect(p.creates[1].data['lat'], isNull);
      expect(p.newWithoutPin.single.name, 'B Co');
      expect(p.newWithUnreadablePin.single.name, 'C Co');
    });

    test('uses resolved short links', () {
      final p = plan(
        [['C Co', '', 'https://maps.app.goo.gl/x', '', '']],
        resolved: {'https://maps.app.goo.gl/x': (lat: 21.5, lng: 39.2)},
      );
      expect(p.creates.single.data['lat'], 21.5);
    });

    test('merges rows with the same VAT', () {
      final p = plan([
        ['Main', '300', '', '', ''],
        ['Branch', '300', 'https://maps.google.com/?q=24.1,46.1', '', ''],
      ]);
      expect(p.mergedDuplicates.single, hasLength(2));
      expect(p.creates.single.name, 'Branch');
      expect(p.creates.single.data['aliases'], ['Main']);
    });

    test('matches by VAT, then by name, and keeps the existing assignment', () {
      final p = plan([
        ['Renamed', '300', '', 'Sami @ Sales', ''],
        ['No Vat Co', '', '', '', 'Jeddah'],
      ], existing: [
        existingClient(id: 'a', vat: '300', name: 'Old name', assignedTo: 'u9'),
        existingClient(id: 'b', name: 'no vat co'),
      ]);
      expect(p.creates, isEmpty);
      final byId = {for (final u in p.updates) u.existingId: u.data};
      expect(byId['a']!['name'], 'Renamed');
      expect(byId['a']!.containsKey('assignedTo'), isFalse);
      expect(byId['b']!['city'], 'Jeddah');
    });

    test('does not match a same-name client that has a different VAT', () {
      final p = plan(
        [['Same', '111', 'https://maps.google.com/?q=24.1,46.1', '', '']],
        existing: [existingClient(vat: '222', name: 'Same')],
      );
      expect(p.updates, isEmpty);
      expect(p.creates, hasLength(1));
    });

    test('adds a location to an existing client once its pin can be read', () {
      final p = plan(
        [['A', '', 'https://maps.app.goo.gl/x', '', '']],
        existing: [existingClient(name: 'A', pin: 'https://maps.app.goo.gl/x')],
        resolved: {'https://maps.app.goo.gl/x': (lat: 21.5, lng: 39.2)},
      );
      expect(p.updates.single.data, {'lat': 21.5, 'lng': 39.2});
    });

    test('counts unchanged rows', () {
      final p = plan([['A', '', '', '', '']], existing: [existingClient(name: 'A')]);
      expect(p.unchanged, 1);
      expect(p.updates, isEmpty);
    });
  });

  group('Odoo details', () {
    test('child contacts "Company, Person" attach to the company', () {
      final p = buildPlan(
        rows: parseOdooTable([
          ['Complete Name', 'Is a Company', 'Mobile', 'Google Pin', 'Company Name', 'Total Receivable', 'State'],
          ['RAZIN FURNITURE', '1', '', 'https://maps.google.com/?q=24.1,46.1', 'رزين للأثاث', '1500.5', 'Riyadh (SA)'],
          ['RAZIN FURNITURE, Atef Dawood', '0', '+966 50 013 9006', '', '', '', ''],
        ]),
        existing: const [],
        resolvedPins: const {},
        salespersonToUid: const {},
      );
      expect(p.creates.single.name, 'RAZIN FURNITURE');
      expect(p.linkedContacts.single.name, 'RAZIN FURNITURE, Atef Dawood');
      final data = p.creates.single.data;
      expect(data['contacts'], [
        {'name': 'Atef Dawood', 'phone': '', 'mobile': '+966 50 013 9006'},
      ]);
      expect(data['legalName'], 'رزين للأثاث');
      expect(data['receivable'], 1500.5);
      expect(data['state'], 'Riyadh (SA)');
    });

    test('a person whose name has a comma but no matching company stays a client', () {
      final p = buildPlan(
        rows: parseOdooTable([
          ['Complete Name', 'Is a Company', 'Google Pin'],
          ['Smith, John', '0', 'https://maps.google.com/?q=24.1,46.1'],
        ]),
        existing: const [],
        resolvedPins: const {},
        salespersonToUid: const {},
      );
      expect(p.creates.single.name, 'Smith, John');
      expect(p.linkedContacts, isEmpty);
    });
  });

  test('Odoo salesperson matches active sales executives and KAMs, not managers', () {
    AppUser u(String id, UserRole role, String odooName, {bool active = true}) =>
        AppUser(id: id, name: id, email: '', phone: '', role: role, kamId: null, active: active, odooName: odooName);
    final map = uidBySalesperson([
      u('sami', UserRole.salesExec, 'Sami Mansour @ Sales'),
      u('kam', UserRole.kam, 'Ahmed @ Sales'),
      u('gm', UserRole.gm, 'Boss'),
      u('left', UserRole.salesExec, 'Old Rep', active: false),
      u('none', UserRole.salesExec, ''),
    ]);
    expect(map, {'sami mansour @ sales': 'sami', 'ahmed @ sales': 'kam'});
  });

  group('Contact person, client type, company ID', () {
    const h = ['Complete Name', 'Tax ID', 'Is a Company', 'Contact Person', 'Company ID', 'Google Pin', 'Salesperson'];
    List<ImportRow> rows(List<List<String>> r) => parseOdooTable([h, ...r]);

    test('parses the columns and drops placeholder contact names', () {
      final r = rows([
        ['A Co', '', 'true', 'Ahmad', '1010 918165', '', ''],
        ['B', '', 'false', '+966 50 342 9632', '', '', ''],
        ['C', '', '', '.', '', '', ''],
        ['D', '', '1', 'Contact', '', '', ''],
      ]);
      expect([for (final x in r) x.clientType], [clientTypeCompany, clientTypeIndividual, '', clientTypeCompany]);
      expect([for (final x in r) x.contactPerson], ['Ahmad', '', '', '']);
      expect(r.first.companyId, '1010918165');
    });

    test('a normal import writes them', () {
      final p = buildPlan(
        rows: rows([['A Co', '', 'true', 'Ahmad', '1010', '', '']]),
        existing: const [],
        resolvedPins: const {},
        salespersonToUid: const {},
      );
      expect(p.creates.single.data, containsPair('clientType', clientTypeCompany));
      expect(p.creates.single.data, containsPair('companyId', '1010'));
      expect(p.creates.single.data, containsPair('contactPerson', 'Ahmad'));
    });

    test('fill only: fills empty fields of matched clients and nothing else', () {
      final existing = [
        existingClient(id: 'c1', vat: '300', name: 'A Co', assignedTo: 'u9', lat: 24),
        Client(
          id: 'c2', vat: '', nameKey: 'b co', name: 'B Co', aliases: const [], phone: '', mobile: '',
          address: '', city: '', tags: '', odooSalesperson: '', googlePin: '', lat: null, lng: null,
          assignedTo: null, category: 'B', lastVisitAt: null, contactPerson: 'Kept', clientType: clientTypeIndividual,
        ),
      ];
      final p = buildPlan(
        rows: rows([
          ['A Co renamed', '300', 'true', 'Ahmad', '1010', 'https://maps.google.com/?q=1.0,2.0', 'Sami @ Sales'],
          ['B Co', '', 'true', 'Omar', '2020', '', ''],
          ['New Co', '', 'true', 'Ali', '3030', '', ''],
        ]),
        existing: existing,
        resolvedPins: const {},
        salespersonToUid: {'sami @ sales': 'u1'},
        fillOnly: true,
      );
      expect(p.creates, isEmpty);
      expect({for (final w in p.updates) w.existingId: w.data}, {
        'c1': {'contactPerson': 'Ahmad', 'clientType': clientTypeCompany, 'companyId': '1010'},
        'c2': {'companyId': '2020'},
      });
      expect(p.unchanged, 1);
    });

    test('fill only: takes a value from another row with the same VAT', () {
      final p = buildPlan(
        rows: rows([
          ['A Co', '300', 'true', '', '', '', ''],
          ['A Co branch', '300', 'true', 'Sami', '', '', ''],
        ]),
        existing: [existingClient(vat: '300', name: 'A Co')],
        resolvedPins: const {},
        salespersonToUid: const {},
        fillOnly: true,
      );
      expect(p.updates.single.data, {'contactPerson': 'Sami', 'clientType': clientTypeCompany});
    });
  });
}
