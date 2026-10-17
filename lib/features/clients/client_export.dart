import 'package:excel/excel.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'client_tags.dart';
import 'visit_rules.dart';

/// A column of the clients Excel export (web dashboard, Clients list). The
/// enum order is the column order; [id] is what the chosen columns are saved
/// as in shared preferences.
enum ExportField {
  name('name'),
  legalName('legalName'),
  vat('vat'),
  companyId('companyId'),
  clientType('clientType'),
  category('category'),
  visitStatus('visitStatus'),
  lastVisit('lastVisit'),
  daysSinceVisit('daysSinceVisit'),
  salesperson('salesperson'),
  odooSalesperson('odooSalesperson'),
  contactPerson('contactPerson'),
  phone('phone'),
  mobile('mobile'),
  email('email'),
  otherContacts('otherContacts'),
  address('address'),
  street('street'),
  city('city'),
  region('region'),
  country('country'),
  latitude('latitude'),
  longitude('longitude'),
  mapsLink('mapsLink'),
  googlePin('googlePin'),
  tags('tags'),
  odooTags('odooTags'),
  receivable('receivable'),
  payable('payable'),
  currency('currency'),
  aliases('aliases'),
  notes('notes'),
  source('source'),
  hidden('hidden'),
  createdAt('createdAt');

  const ExportField(this.id);
  final String id;

  String label(AppLocalizations l10n) => switch (this) {
        name => l10n.name,
        legalName => l10n.exportLegalName,
        vat => l10n.vat,
        companyId => l10n.companyId,
        clientType => l10n.clientType,
        category => l10n.category,
        visitStatus => l10n.exportVisitStatus,
        lastVisit => l10n.lastVisit,
        daysSinceVisit => l10n.exportDaysSinceVisit,
        salesperson => l10n.salesExecutive,
        odooSalesperson => l10n.odooSalesperson,
        contactPerson => l10n.contactPerson,
        phone => l10n.phone,
        mobile => l10n.mobile,
        email => l10n.email,
        otherContacts => l10n.exportOtherContacts,
        address => l10n.address,
        street => l10n.street,
        city => l10n.city,
        region => l10n.region,
        country => l10n.country,
        latitude => l10n.latitude,
        longitude => l10n.longitude,
        mapsLink => l10n.exportMapsLink,
        googlePin => l10n.exportGooglePin,
        tags => l10n.clientTags,
        odooTags => l10n.exportOdooTags,
        receivable => l10n.receivable,
        payable => l10n.payable,
        currency => l10n.exportCurrency,
        aliases => l10n.mergedContacts,
        notes => l10n.notes,
        source => l10n.exportSource,
        hidden => l10n.exportHidden,
        createdAt => l10n.exportAddedOn,
      };

  static List<ExportField> fromIds(Iterable<String> ids) {
    final set = ids.toSet();
    return [for (final f in values) if (set.contains(f.id)) f];
  }
}

/// What the cell values need besides the client itself.
class ClientExportContext {
  const ClientExportContext({
    required this.l10n,
    required this.languageCode,
    required this.userNames,
    required this.tags,
    required this.rules,
    required this.now,
  });

  final AppLocalizations l10n;
  final String languageCode;

  /// uid → name, for the salesperson column.
  final Map<String, String> userNames;
  final Map<String, ClientTag> tags;
  final VisitRules rules;
  final DateTime now;
}

/// The cell value of [field] for [c]: a String, num, DateTime or null (empty).
Object? exportValue(ExportField field, Client c, ClientExportContext x) {
  final l10n = x.l10n;
  String? text(String s) => s.trim().isEmpty ? null : s.trim();
  return switch (field) {
    ExportField.name => c.name,
    ExportField.legalName => text(c.legalName),
    ExportField.vat => text(c.vat),
    ExportField.companyId => text(c.companyId),
    ExportField.clientType => switch (c.clientType) {
        clientTypeCompany => l10n.clientTypeCompany,
        clientTypeIndividual => l10n.clientTypeIndividual,
        _ => null,
      },
    ExportField.category => c.category,
    ExportField.visitStatus => c.lastVisitAt == null ? l10n.never : visitStatusLabel(visitStatus(c, x.rules, x.now), l10n),
    ExportField.lastVisit => c.lastVisitAt,
    ExportField.daysSinceVisit => c.lastVisitAt == null ? null : x.now.difference(c.lastVisitAt!).inDays,
    ExportField.salesperson => c.assignedTo == null ? l10n.unassigned : x.userNames[c.assignedTo] ?? l10n.unassigned,
    ExportField.odooSalesperson => text(c.odooSalesperson),
    ExportField.contactPerson => text(c.contactPerson),
    ExportField.phone => text(c.phone),
    ExportField.mobile => text(c.mobile),
    ExportField.email => text(c.email),
    ExportField.otherContacts => text([
        for (final p in c.contacts) [p.name, p.phone, p.mobile].where((s) => s.trim().isNotEmpty).join(' – '),
      ].where((s) => s.isNotEmpty).join('\n')),
    ExportField.address => text(c.address),
    ExportField.street => text(c.street),
    ExportField.city => text(c.city),
    ExportField.region => text(c.state),
    ExportField.country => text(c.country),
    ExportField.latitude => c.lat,
    ExportField.longitude => c.lng,
    ExportField.mapsLink => c.hasLocation ? 'https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}' : null,
    ExportField.googlePin => text(c.googlePin),
    ExportField.tags => text([
        for (final id in c.tagIds)
          if (x.tags[id] case final t?) t.label(x.languageCode),
      ].join(', ')),
    ExportField.odooTags => text(c.tags),
    ExportField.receivable => c.receivable,
    ExportField.payable => c.payable,
    ExportField.currency => text(c.currency),
    ExportField.aliases => text(c.aliases.join(', ')),
    ExportField.notes => text(c.notes),
    ExportField.source => c.source == 'manual' ? l10n.addedInApp : l10n.exportSourceImport,
    ExportField.hidden => c.hidden ? l10n.yes : l10n.no,
    ExportField.createdAt => c.createdAt,
  };
}

/// One "Clients" sheet: a bold header row of [fields], then one row per
/// client. Right-to-left in Arabic.
List<int> buildClientsXlsx(List<Client> clients, List<ExportField> fields, ClientExportContext x) {
  final excel = Excel.createExcel();
  const sheetName = 'Clients';
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
  excel.setDefaultSheet(sheetName);
  final sheet = excel[sheetName];
  sheet.isRTL = x.languageCode == 'ar';

  final bold = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#FFE8EEF4'));
  for (final (i, f) in fields.indexed) {
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), TextCellValue(f.label(x.l10n)),
        cellStyle: bold);
    sheet.setColumnWidth(i, switch (f) {
      ExportField.name || ExportField.legalName || ExportField.address || ExportField.mapsLink => 40,
      ExportField.otherContacts || ExportField.notes || ExportField.aliases || ExportField.googlePin => 35,
      _ => 18,
    });
  }
  for (final c in clients) {
    sheet.appendRow([for (final f in fields) _cell(exportValue(f, c, x))]);
  }
  return excel.encode()!;
}

CellValue? _cell(Object? v) => switch (v) {
      null => null,
      final int n => IntCellValue(n),
      final double n => DoubleCellValue(n),
      final DateTime d => DateCellValue(year: d.year, month: d.month, day: d.day),
      _ => TextCellValue('$v'),
    };
