import '../clients/client.dart';
import 'plus_code.dart';

/// One contact row from the Odoo "Contact (res.partner)" export.
class ImportRow {
  const ImportRow({
    required this.rowNumber,
    required this.name,
    required this.vat,
    required this.phone,
    required this.mobile,
    required this.address,
    required this.city,
    required this.tags,
    required this.salesperson,
    required this.pinUrl,
    this.category = '',
    this.email = '',
    this.contactPerson = '',
    this.legalName = '',
    this.isCompany = true,
    this.clientType = '',
    this.companyId = '',
    this.street = '',
    this.state = '',
    this.country = '',
    this.receivable = 0,
    this.payable = 0,
    this.currency = '',
  });

  /// 1-based spreadsheet row, for error messages.
  final int rowNumber;
  final String name;
  final String vat;
  final String phone;
  final String mobile;
  final String address;
  final String city;
  final String tags;
  final String salesperson;

  /// The Google Maps link from "Google Pin", or empty.
  final String pinUrl;

  /// 'A', 'B' or 'C' from an optional "Category" column; empty when absent.
  final String category;

  /// From optional "Email" and "Contact Person" columns; empty when absent.
  final String email;
  final String contactPerson;

  /// Odoo "Company Name": the registered name, often in Arabic.
  final String legalName;
  final bool isCompany;

  /// [clientTypeCompany] / [clientTypeIndividual] from "Is a Company";
  /// empty when the cell is empty.
  final String clientType;

  /// Odoo "Company ID" (commercial registration number), or empty.
  final String companyId;
  final String street;
  final String state;
  final String country;
  final double receivable;
  final double payable;
  final String currency;

  String get nameKey => Client.normalizeName(name);
}

class OdooParseException implements Exception {
  OdooParseException(this.missingColumn);
  final String missingColumn;
  @override
  String toString() => 'Missing column "$missingColumn"';
}

/// Parses the export into rows. [table] is the sheet with its header row first.
List<ImportRow> parseOdooTable(List<List<String>> table) {
  if (table.isEmpty) throw OdooParseException('Complete Name');
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  int col(String name) => header.indexOf(name.toLowerCase());
  final nameCol = col('Complete Name');
  if (nameCol < 0) throw OdooParseException('Complete Name');
  final cols = {
    for (final c in [
      'Tax ID', 'Phone', 'Mobile', 'Contact Address Complete', 'Street',
      'City', 'Tags', 'Salesperson', 'Google Pin', 'Category', 'Email', 'Contact Person',
      'Company Name', 'Is a Company', 'State', 'Country', 'Total Receivable', 'Total Payable', 'Currency', 'Company ID',
    ])
      c: col(c),
  };

  final rows = <ImportRow>[];
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    String cell(String name) {
      final c = name == 'Complete Name' ? nameCol : cols[name]!;
      return c >= 0 && c < r.length ? r[c].trim() : '';
    }

    final name = cell('Complete Name');
    if (name.isEmpty) continue;
    final address = cell('Contact Address Complete');
    rows.add(ImportRow(
      rowNumber: i + 1,
      name: name,
      vat: cell('Tax ID').replaceAll(RegExp(r'\s'), ''),
      phone: cell('Phone'),
      mobile: cell('Mobile'),
      address: address.isNotEmpty ? address : cell('Street'),
      city: cell('City'),
      tags: cell('Tags'),
      salesperson: cell('Salesperson'),
      pinUrl: extractUrl(cell('Google Pin')),
      category: parseCategory(cell('Category')),
      email: cell('Email'),
      contactPerson: cleanContactPerson(cell('Contact Person')),
      legalName: cell('Company Name') == '0' ? '' : cell('Company Name'),
      // Excel stores this as a boolean ("false"), CSV as "0".
      isCompany: !const {'0', 'false', 'no'}.contains(cell('Is a Company').toLowerCase()),
      clientType: parseClientType(cell('Is a Company')),
      companyId: cell('Company ID').replaceAll(RegExp(r'\s'), ''),
      street: cell('Street'),
      state: cell('State'),
      country: cell('Country'),
      receivable: double.tryParse(cell('Total Receivable')) ?? 0,
      payable: double.tryParse(cell('Total Payable')) ?? 0,
      currency: cell('Currency'),
    ));
  }
  return rows;
}

/// "A", "a", "Category B" or "Class C" → the letter; anything else → empty.
String parseCategory(String cell) =>
    RegExp(r'^(?:category|class)?\s*([abc])$', caseSensitive: false).firstMatch(cell.trim())?.group(1)?.toUpperCase() ?? '';

/// Pulls the first http(s) link out of a cell like "Factory https://maps...".
String extractUrl(String cell) =>
    RegExp(r'https?://\S+').firstMatch(cell)?.group(0) ?? '';

const _shortLinkHosts = {'maps.app.goo.gl', 'goo.gl', 'share.google', 'g.co'};

/// Short links hide the coordinates behind a redirect and must be resolved
/// by the `resolvePins` Cloud Function (browsers can't follow them).
bool isShortLink(String url) =>
    _shortLinkHosts.contains(Uri.tryParse(url)?.host.toLowerCase());

/// Reads coordinates from a full Google Maps URL. Place coordinates
/// (`!3d..!4d..`) win over query params, which win over the `@` viewport;
/// last resort: a Plus Code in the place name.
({double lat, double lng})? coordsFromUrl(String url) {
  final s = Uri.decodeFull(url.replaceAll('+', ' '));
  const n = r'(-?\d{1,3}\.\d+)';
  for (final pattern in [
    '!3d$n!4d$n',
    '[?&](?:q|query|ll|destination|center)=$n,\\s*$n',
    '@$n,$n',
  ]) {
    final m = RegExp(pattern).firstMatch(s);
    if (m == null) continue;
    final lat = double.parse(m.group(1)!);
    final lng = double.parse(m.group(2)!);
    if (lat.abs() <= 90 && lng.abs() <= 180) return (lat: lat, lng: lng);
  }
  // Place links shared without coordinates carry a Plus Code instead.
  return coordsFromPlusCode(s);
}

/// "Is a Company" cell → client type; empty when the cell is empty or unknown.
String parseClientType(String cell) => switch (cell.trim().toLowerCase()) {
      '1' || 'true' || 'yes' => clientTypeCompany,
      '0' || 'false' || 'no' => clientTypeIndividual,
      _ => '',
    };

/// Odoo's "Contact Person" holds placeholders (".", "Contact") and phone
/// numbers too; keeps only text that looks like a name.
String cleanContactPerson(String cell) {
  final v = cell.trim();
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(v)) return '';
  if (const {'contact', 'n/a', 'na', 'none'}.contains(v.toLowerCase())) return '';
  return v;
}
