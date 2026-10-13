import '../clients/client.dart';
import 'odoo_parser.dart';

typedef Coords = ({double lat, double lng});

class PlannedWrite {
  const PlannedWrite({required this.existingId, required this.name, required this.data});

  /// null when this creates a new client.
  final String? existingId;
  final String name;

  /// Fields to write: the full client for a create, only changed fields for an update.
  final Map<String, dynamic> data;
}

class ImportPlan {
  const ImportPlan({
    required this.creates,
    required this.updates,
    required this.unchanged,
    required this.newWithoutPin,
    required this.newWithUnreadablePin,
    required this.mergedDuplicates,
    this.linkedContacts = const [],
  });

  final List<PlannedWrite> creates;
  final List<PlannedWrite> updates;
  final int unchanged;

  /// New clients created without a location because Odoo has no Google Pin.
  final List<ImportRow> newWithoutPin;

  /// New clients created without a location because their pin couldn't be read.
  final List<ImportRow> newWithUnreadablePin;

  /// Rows sharing one VAT number, merged into a single client.
  final List<List<ImportRow>> mergedDuplicates;

  /// Odoo child contacts ("Company, Person") attached to their company as
  /// contact people instead of becoming clients.
  final List<ImportRow> linkedContacts;
}

String normalizeSalesperson(String name) => name.trim().toLowerCase();

/// Compares the export with the clients already in Firestore.
///
/// Rows are matched by VAT, or by normalized name when there is no VAT
/// (a client that later gets a VAT in Odoo is still matched by its name).
/// Existing clients keep their app-side data (assignment, green period,
/// visits); a salesperson from Odoo only fills an empty assignment.
ImportPlan buildPlan({
  required List<ImportRow> rows,
  required List<Client> existing,
  required Map<String, Coords> resolvedPins,
  required Map<String, String> salespersonToUid,
}) {
  // Odoo names a child contact "Parent, Person": attach it to the parent.
  final byNameKey = {for (final r in rows) r.nameKey: r};
  final contactsOf = <String, List<ImportRow>>{};
  final linked = <ImportRow>[];
  final clientRows = <ImportRow>[];
  for (final r in rows) {
    final comma = r.name.indexOf(', ');
    final parent = comma > 0 && !r.isCompany ? byNameKey[Client.normalizeName(r.name.substring(0, comma))] : null;
    if (parent != null && parent != r) {
      contactsOf.putIfAbsent(parent.nameKey, () => []).add(r);
      linked.add(r);
    } else {
      clientRows.add(r);
    }
  }

  final groups = <String, List<ImportRow>>{};
  for (final r in clientRows) {
    groups.putIfAbsent(r.vat.isNotEmpty ? 'vat:${r.vat}' : 'name:${r.nameKey}', () => []).add(r);
  }

  final byVat = {for (final c in existing) if (c.vat.isNotEmpty) c.vat: c};
  final byName = {for (final c in existing) c.nameKey: c};
  final usedIds = <String>{};

  final creates = <PlannedWrite>[];
  final updates = <PlannedWrite>[];
  final newWithoutPin = <ImportRow>[];
  final newWithUnreadablePin = <ImportRow>[];
  final merged = <List<ImportRow>>[];
  var unchanged = 0;

  Coords? coordsOf(ImportRow r) =>
      r.pinUrl.isEmpty ? null : coordsFromUrl(r.pinUrl) ?? resolvedPins[r.pinUrl];

  for (final group in groups.values) {
    if (group.length > 1) merged.add(group);
    final primary = group.firstWhere((r) => coordsOf(r) != null, orElse: () => group.first);
    final coords = coordsOf(primary);
    final aliases = {
      for (final r in group)
        if (r.nameKey != primary.nameKey) r.name,
    }.toList();

    var match = primary.vat.isNotEmpty ? byVat[primary.vat] : null;
    if (match == null) {
      // A name match must not be a different company with its own VAT.
      final named = byName[primary.nameKey];
      if (named != null && (named.vat.isEmpty || primary.vat.isEmpty)) match = named;
    }
    if (match != null && !usedIds.add(match.id)) match = null;
    final uid = salespersonToUid[normalizeSalesperson(primary.salesperson)];

    final odooFields = <String, dynamic>{
      'vat': primary.vat,
      'nameKey': primary.nameKey,
      'name': primary.name,
      'aliases': aliases,
      'phone': primary.phone,
      'mobile': primary.mobile,
      'address': primary.address,
      'city': primary.city,
      'tags': primary.tags,
      'odooSalesperson': primary.salesperson,
      'googlePin': primary.pinUrl,
      // Only when the sheet has a category; otherwise keep the app's value.
      if (primary.category.isNotEmpty) 'category': primary.category,
      if (primary.email.isNotEmpty) 'email': primary.email,
      if (primary.contactPerson.isNotEmpty) 'contactPerson': primary.contactPerson,
      'legalName': primary.legalName,
      'street': primary.street,
      'state': primary.state,
      'country': primary.country,
      'receivable': primary.receivable,
      'payable': primary.payable,
      'currency': primary.currency,
      'contacts': {
        // Identical rows in Odoo would otherwise list a contact twice.
        for (final r in group.expand((g) => contactsOf[g.nameKey] ?? const <ImportRow>[]))
          '${Client.normalizeName(r.name)}|${r.phone}|${r.mobile}': {
            'name': r.name.substring(r.name.indexOf(', ') + 2),
            'phone': r.phone,
            'mobile': r.mobile,
          },
      }.values.toList(),
    };

    if (match == null) {
      // Clients without a location are kept; they show on the map once one is set.
      if (coords == null) {
        (primary.pinUrl.isEmpty ? newWithoutPin : newWithUnreadablePin).add(primary);
      }
      creates.add(PlannedWrite(existingId: null, name: primary.name, data: {
        ...odooFields,
        'lat': coords?.lat,
        'lng': coords?.lng,
        'assignedTo': uid,
        'lastVisitAt': null,
        'source': 'import',
      }));
      continue;
    }

    final current = <String, dynamic>{
      'vat': match.vat,
      'nameKey': match.nameKey,
      'name': match.name,
      'aliases': match.aliases,
      'phone': match.phone,
      'mobile': match.mobile,
      'address': match.address,
      'city': match.city,
      'tags': match.tags,
      'odooSalesperson': match.odooSalesperson,
      'googlePin': match.googlePin,
      'category': match.category,
      'email': match.email,
      'contactPerson': match.contactPerson,
      'legalName': match.legalName,
      'street': match.street,
      'state': match.state,
      'country': match.country,
      'receivable': match.receivable,
      'payable': match.payable,
      'currency': match.currency,
      'contacts': [for (final c in match.contacts) c.toMap()],
    };
    final changes = <String, dynamic>{
      for (final e in odooFields.entries)
        if (!_same(e.value, current[e.key])) e.key: e.value,
    };
    if (coords != null && (primary.pinUrl != match.googlePin || !match.hasLocation)) {
      if (coords.lat != match.lat || coords.lng != match.lng) {
        changes['lat'] = coords.lat;
        changes['lng'] = coords.lng;
      }
    }
    if (match.assignedTo == null && uid != null) changes['assignedTo'] = uid;

    if (changes.isEmpty) {
      unchanged++;
    } else {
      updates.add(PlannedWrite(existingId: match.id, name: primary.name, data: changes));
    }
  }

  return ImportPlan(
    creates: creates,
    updates: updates,
    unchanged: unchanged,
    newWithoutPin: newWithoutPin,
    newWithUnreadablePin: newWithUnreadablePin,
    mergedDuplicates: merged,
    linkedContacts: linked,
  );
}

bool _same(Object? a, Object? b) => switch ((a, b)) {
      (List a, List b) => a.length == b.length && [for (var i = 0; i < a.length; i++) _same(a[i], b[i])].every((x) => x),
      (Map a, Map b) => a.length == b.length && a.keys.every((k) => _same(a[k], b[k])),
      (num a, num b) => a == b,
      _ => a == b,
    };
