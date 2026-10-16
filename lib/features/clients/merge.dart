import 'package:cloud_firestore/cloud_firestore.dart';

import 'client.dart';

/// A client merged into another one (`clients/{id}.mergedFrom`). The Odoo
/// import skips rows that match it, so a merged client doesn't come back.
class MergedClient {
  const MergedClient({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.vat,
    required this.byId,
    required this.at,
  });

  final String id;
  final String name;
  final String nameKey;
  final String vat;
  final String byId;
  final DateTime? at;

  factory MergedClient.fromMap(Map<dynamic, dynamic> m) => MergedClient(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        nameKey: m['nameKey'] as String? ?? '',
        vat: m['vat'] as String? ?? '',
        byId: m['byId'] as String? ?? '',
        at: (m['at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameKey': nameKey,
        'vat': vat,
        'byId': byId,
        'at': at == null ? null : Timestamp.fromDate(at!),
      };
}

/// The update for [keep] when [others] are merged into it: empty fields are
/// filled from the others, their names become aliases, contacts are joined,
/// the latest visit counts, and the others (with what they had absorbed
/// before) are logged in `mergedFrom`. The kept client's name, category and
/// salesperson stay (the salesperson only fills an empty one).
Map<String, dynamic> mergeUpdate(Client keep, List<Client> others, {required String byId, required DateTime at}) {
  String fill(String Function(Client) field) =>
      [keep, ...others].map(field).firstWhere((v) => v.trim().isNotEmpty, orElse: () => field(keep));

  final located = [keep, ...others].where((c) => c.hasLocation).firstOrNull;
  final lastVisit = [keep, ...others]
      .map((c) => c.lastVisitAt)
      .nonNulls
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  final mergedIds = {for (final o in others) o.id};

  final aliases = <String, String>{};
  for (final n in [...keep.aliases, for (final o in others) ...[o.name, ...o.aliases]]) {
    final key = Client.normalizeName(n);
    if (key.isNotEmpty && key != keep.nameKey) aliases.putIfAbsent(key, () => n);
  }
  final contacts = <String, Map<String, dynamic>>{};
  for (final c in [keep, ...others].expand((c) => c.contacts)) {
    contacts.putIfAbsent('${Client.normalizeName(c.name)}|${c.phone}|${c.mobile}', c.toMap);
  }
  final notes = [keep, ...others].map((c) => c.notes.trim()).where((n) => n.isNotEmpty).toSet().join('\n\n');

  return {
    'vat': fill((c) => c.vat),
    'phone': fill((c) => c.phone),
    'mobile': fill((c) => c.mobile),
    'email': fill((c) => c.email),
    'contactPerson': fill((c) => c.contactPerson),
    'address': fill((c) => c.address),
    'city': fill((c) => c.city),
    'street': fill((c) => c.street),
    'state': fill((c) => c.state),
    'country': fill((c) => c.country),
    'legalName': fill((c) => c.legalName),
    'googlePin': located?.googlePin.isNotEmpty ?? false ? located!.googlePin : fill((c) => c.googlePin),
    'notes': notes,
    'lat': located?.lat,
    'lng': located?.lng,
    'assignedTo': keep.assignedTo ?? others.map((c) => c.assignedTo).nonNulls.firstOrNull,
    'lastVisitAt': lastVisit == null ? null : Timestamp.fromDate(lastVisit),
    'aliases': aliases.values.toList(),
    'contacts': contacts.values.toList(),
    'notDuplicates': {
      for (final id in [keep, ...others].expand((c) => c.notDuplicates))
        if (id != keep.id && !mergedIds.contains(id)) id,
    }.toList(),
    'mergedFrom': [
      for (final m in keep.mergedFrom) m.toMap(),
      for (final o in others) ...[
        MergedClient(id: o.id, name: o.name, nameKey: o.nameKey, vat: o.vat, byId: byId, at: at).toMap(),
        for (final m in o.mergedFrom) m.toMap(),
      ],
    ],
  };
}

/// The client to keep by default: from Odoo, with a Tax ID, a location and
/// the most recent visit, in that order.
Client suggestedKeep(List<Client> group) {
  int score(Client c) =>
      (c.source == 'import' ? 8 : 0) + (c.vat.isNotEmpty ? 4 : 0) + (c.hasLocation ? 2 : 0) + (c.assignedTo != null ? 1 : 0);
  return (List.of(group)
        ..sort((a, b) {
          final s = score(b).compareTo(score(a));
          if (s != 0) return s;
          return (b.lastVisitAt ?? DateTime(0)).compareTo(a.lastVisitAt ?? DateTime(0));
        }))
      .first;
}
