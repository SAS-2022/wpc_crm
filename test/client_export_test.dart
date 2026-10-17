import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_export.dart';
import 'package:wpc_crm/features/clients/client_tags.dart';
import 'package:wpc_crm/features/clients/visit_rules.dart';
import 'package:wpc_crm/l10n/app_localizations.dart';

Client client({
  String name = 'Acme',
  String? assignedTo,
  DateTime? lastVisit,
  double? lat,
  double? lng,
  List<String> tagIds = const [],
  List<ClientContact> contacts = const [],
  String clientType = '',
}) =>
    Client(
      id: name, vat: '300123', nameKey: name.toLowerCase(), name: name, aliases: const ['Acme Trading'],
      phone: '011', mobile: '', address: '', city: 'Riyadh', tags: '', odooSalesperson: '', googlePin: '',
      lat: lat, lng: lng, assignedTo: assignedTo, category: 'A', lastVisitAt: lastVisit, tagIds: tagIds,
      contacts: contacts, clientType: clientType, receivable: 1250.5,
    );

void main() {
  final now = DateTime(2026, 10, 17, 12);
  ClientExportContext ctx(String lang) => ClientExportContext(
        l10n: lookupAppLocalizations(Locale(lang)),
        languageCode: lang,
        userNames: const {'u1': 'Sami'},
        tags: {for (final t in defaultClientTags) t.id: t},
        rules: VisitRules.defaults,
        now: now,
      );

  test('values: salesperson, status, days, tags, contacts, maps link', () {
    final x = ctx('en');
    final c = client(
      assignedTo: 'u1',
      lastVisit: now.subtract(const Duration(days: 3)),
      lat: 24.7,
      lng: 46.6,
      tagIds: ['factory', 'gone'],
      contacts: const [ClientContact(name: 'Ali', phone: '055', mobile: '')],
      clientType: clientTypeCompany,
    );
    expect(exportValue(ExportField.salesperson, c, x), 'Sami');
    expect(exportValue(ExportField.visitStatus, c, x), x.l10n.statusRecent);
    expect(exportValue(ExportField.daysSinceVisit, c, x), 3);
    expect(exportValue(ExportField.tags, c, x), 'Factory');
    expect(exportValue(ExportField.otherContacts, c, x), 'Ali – 055');
    expect(exportValue(ExportField.clientType, c, x), 'Company');
    expect(exportValue(ExportField.mapsLink, c, x), contains('24.7,46.6'));
    expect(exportValue(ExportField.receivable, c, x), 1250.5);
    expect(exportValue(ExportField.aliases, c, x), 'Acme Trading');
  });

  test('empty values: unassigned, never visited, no location', () {
    final x = ctx('en');
    final c = client();
    expect(exportValue(ExportField.salesperson, c, x), x.l10n.unassigned);
    expect(exportValue(ExportField.visitStatus, c, x), x.l10n.never);
    expect(exportValue(ExportField.daysSinceVisit, c, x), isNull);
    expect(exportValue(ExportField.mapsLink, c, x), isNull);
    expect(exportValue(ExportField.legalName, c, x), isNull);
    expect(exportValue(ExportField.clientType, c, x), isNull);
  });

  test('field ids round-trip in column order', () {
    expect(ExportField.fromIds(['city', 'name', 'unknown']), [ExportField.name, ExportField.city]);
  });

  test('xlsx: header row of the chosen columns, then one row per client', () {
    final fields = [ExportField.name, ExportField.city, ExportField.latitude];
    final bytes = buildClientsXlsx(
      [client(name: 'A', lat: 24.5, lng: 46), client(name: 'B')],
      fields,
      ctx('ar'),
    );
    final sheet = Excel.decodeBytes(bytes).tables['Clients']!;
    final rows = sheet.rows.map((r) => r.map((c) => c?.value?.toString()).toList()).toList();
    expect(rows[0], ['الاسم', 'المدينة', 'خط العرض']);
    expect(rows[1], ['A', 'Riyadh', '24.5']);
    expect(rows[2], ['B', 'Riyadh', null]);
    expect(rows.length, 3);
  });
}
