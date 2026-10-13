import '../clients/client.dart';
import 'import_plan.dart';
import 'odoo_parser.dart';

/// One row of a "client name → location" sheet.
class LocationRow {
  const LocationRow({
    required this.rowNumber,
    required this.name,
    required this.vat,
    required this.link,
    required this.coords,
    this.area = '',
    this.salesperson = '',
    this.note = '',
  });

  final int rowNumber;
  final String name;
  final String vat;

  /// Area / city column, used when the row becomes a new client.
  final String area;

  /// Odoo salesperson from a pivot export's header cell.
  final String salesperson;

  /// Text in the location cell that is neither a link nor coordinates
  /// (e.g. "no location"), kept as the new client's notes.
  final String note;

  /// Google Maps link, when the location was given as one.
  final String link;

  /// Coordinates readable without the server (lat/lng columns, plain
  /// "24.7, 46.6" text or a full Google Maps URL).
  final Coords? coords;
}

class LocationUpdate {
  const LocationUpdate({required this.client, required this.row, required this.coords});

  final Client client;
  final LocationRow row;
  final Coords coords;

  bool get replacesExisting => client.hasLocation;
}

class LocationPlan {
  const LocationPlan({
    required this.updates,
    required this.unchanged,
    required this.notFound,
    required this.ambiguous,
    required this.unreadable,
    this.newClients = const [],
  });

  final List<LocationUpdate> updates;

  /// Rows whose client already has exactly this location.
  final int unchanged;

  /// Rows that match no client.
  final List<LocationRow> notFound;

  /// Rows whose name matches more than one client (and no VAT to decide).
  final List<LocationRow> ambiguous;

  /// Rows whose location couldn't be turned into coordinates.
  final List<LocationRow> unreadable;

  /// [notFound] rows that can be added as new clients, one per name, with
  /// their location when it could be read.
  final List<NewLocationClient> newClients;
}

typedef NewLocationClient = ({LocationRow row, Coords? coords});

const _nameHeaders = ['complete name', 'name', 'client', 'client name', 'customer', 'company', 'اسم العميل', 'الاسم', 'العميل'];
const _vatHeaders = ['tax id', 'vat', 'vat number', 'الرقم الضريبي'];
const _linkHeaders = ['google pin', 'location', 'link', 'map', 'google maps', 'pin', 'url', 'الموقع', 'الرابط'];
const _areaHeaders = ['area', 'city', 'district', 'المنطقة', 'المدينة', 'الحي'];
const _latHeaders = ['latitude', 'lat', 'خط العرض'];
const _lngHeaders = ['longitude', 'lng', 'long', 'lon', 'خط الطول'];

class LocationParseException implements Exception {
  const LocationParseException();
  @override
  String toString() => 'Need a name (or Tax ID) column and a location, link or latitude/longitude column';
}

List<LocationRow> parseLocationTable(List<List<String>> table) {
  if (table.isEmpty) throw const LocationParseException();
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  int col(List<String> names) => header.indexWhere(names.contains);
  final vatCol = col(_vatHeaders);
  final linkCol = col(_linkHeaders);
  final latCol = col(_latHeaders);
  final lngCol = col(_lngHeaders);
  final areaCol = col(_areaHeaders);
  // Odoo pivot exports put the salesperson in the first header cell and the
  // client names below it, so fall back to the first unused column.
  var nameCol = col(_nameHeaders);
  var salesperson = '';
  if (nameCol < 0) {
    final used = {vatCol, linkCol, latCol, lngCol, areaCol};
    nameCol = List.generate(header.length, (i) => i).firstWhere((i) => !used.contains(i), orElse: () => -1);
    if (nameCol >= 0) salesperson = table.first[nameCol].trim();
  }
  final hasLatLng = latCol >= 0 && lngCol >= 0;
  if ((nameCol < 0 && vatCol < 0) || (linkCol < 0 && !hasLatLng)) {
    throw const LocationParseException();
  }

  final rows = <LocationRow>[];
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    String cell(int c) => c >= 0 && c < r.length ? r[c].trim() : '';
    final name = cell(nameCol);
    final vat = cell(vatCol).replaceAll(RegExp(r'\s'), '');
    if (name.isEmpty && vat.isEmpty) continue;

    Coords? coords;
    if (hasLatLng) {
      final lat = double.tryParse(cell(latCol));
      final lng = double.tryParse(cell(lngCol));
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) coords = (lat: lat, lng: lng);
    }
    final raw = cell(linkCol);
    final link = extractUrl(raw);
    coords ??= link.isNotEmpty ? coordsFromUrl(link) : coordsFromText(raw);
    rows.add(LocationRow(
      rowNumber: i + 1,
      name: name,
      vat: vat,
      link: link,
      coords: coords,
      area: cell(areaCol).replaceAll(RegExp(r'^[_\-]+$'), ''),
      salesperson: salesperson,
      note: link.isEmpty && coords == null ? raw : '',
    ));
  }
  return rows;
}

/// Reads plain "24.7136, 46.6753" text.
Coords? coordsFromText(String text) {
  final m = RegExp(r'^\s*(-?\d{1,3}\.\d+)\s*[,،]\s*(-?\d{1,3}\.\d+)\s*$').firstMatch(text);
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  return lat.abs() <= 90 && lng.abs() <= 180 ? (lat: lat, lng: lng) : null;
}

/// Matches rows to clients by VAT, else by name (including merged names).
LocationPlan buildLocationPlan({
  required List<LocationRow> rows,
  required List<Client> clients,
  required Map<String, Coords> resolvedLinks,
}) {
  final byVat = <String, List<Client>>{};
  final byName = <String, List<Client>>{};
  for (final c in clients) {
    if (c.vat.isNotEmpty) byVat.putIfAbsent(c.vat, () => []).add(c);
    for (final name in {c.nameKey, for (final a in c.aliases) Client.normalizeName(a)}) {
      byName.putIfAbsent(name, () => []).add(c);
    }
  }

  final updates = <LocationUpdate>[];
  final notFound = <LocationRow>[];
  final ambiguous = <LocationRow>[];
  final unreadable = <LocationRow>[];
  final seen = <String>{};
  var unchanged = 0;

  for (final row in rows) {
    final matches = (row.vat.isNotEmpty ? byVat[row.vat] : null) ?? byName[Client.normalizeName(row.name)] ?? const [];
    if (matches.isEmpty) {
      notFound.add(row);
      continue;
    }
    if (matches.length > 1) {
      ambiguous.add(row);
      continue;
    }
    final coords = row.coords ?? resolvedLinks[row.link];
    if (coords == null) {
      unreadable.add(row);
      continue;
    }
    final client = matches.single;
    if (!seen.add(client.id)) continue; // first row for a client wins
    if (client.lat == coords.lat && client.lng == coords.lng) {
      unchanged++;
    } else {
      updates.add(LocationUpdate(client: client, row: row, coords: coords));
    }
  }

  final newNames = <String>{};
  final newClients = <NewLocationClient>[
    for (final row in notFound)
      if (row.name.isNotEmpty && newNames.add(Client.normalizeName(row.name)))
        (row: row, coords: row.coords ?? resolvedLinks[row.link]),
  ];

  return LocationPlan(
    newClients: newClients,
    updates: updates,
    unchanged: unchanged,
    notFound: notFound,
    ambiguous: ambiguous,
    unreadable: unreadable,
  );
}
