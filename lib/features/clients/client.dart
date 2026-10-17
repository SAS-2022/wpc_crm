import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'merge.dart';
import 'transfer.dart';

/// Values of `clients.clientType`, from Odoo's "Is a Company".
const clientTypeCompany = 'company';
const clientTypeIndividual = 'individual';

class Client {
  const Client({
    required this.id,
    required this.vat,
    required this.nameKey,
    required this.name,
    required this.aliases,
    required this.phone,
    required this.mobile,
    required this.address,
    required this.city,
    required this.tags,
    required this.odooSalesperson,
    required this.googlePin,
    required this.lat,
    required this.lng,
    required this.assignedTo,
    required this.category,
    required this.lastVisitAt,
    this.contactPerson = '',
    this.clientType = '',
    this.companyId = '',
    this.tagIds = const [],
    this.email = '',
    this.notes = '',
    this.source = 'import',
    this.legalName = '',
    this.street = '',
    this.state = '',
    this.country = '',
    this.receivable = 0,
    this.payable = 0,
    this.currency = '',
    this.contacts = const [],
    this.hidden = false,
    this.transfers = const [],
    this.notDuplicates = const [],
    this.mergedFrom = const [],
    this.mainLocationType = '',
    this.extraLocations = const [],
    this.createdAt,
  });

  final String id;

  /// Odoo Tax ID; the import match key when present.
  final String vat;

  /// Normalized name; the import match key when there is no VAT.
  final String nameKey;
  final String name;

  /// Names of Odoo contacts merged into this client (same VAT).
  final List<String> aliases;
  final String phone;
  final String mobile;
  final String address;
  final String city;
  final String tags;

  /// Salesperson as written in Odoo, e.g. "Sami Mansour @ Sales".
  final String odooSalesperson;
  final String googlePin;
  final double? lat;
  final double? lng;

  /// uid of the sales executive responsible for this client.
  final String? assignedTo;

  /// Importance: 'A', 'B' or 'C'. Sets how often the client must be visited
  /// (see VisitRules).
  final String category;
  final DateTime? lastVisitAt;
  final String contactPerson;

  /// [clientTypeCompany], [clientTypeIndividual] or empty (unknown).
  final String clientType;

  /// Commercial registration number ("Company ID" in Odoo).
  final String companyId;

  /// Business tags (Factory, Showroom, …) from `settings/clientTags`.
  final List<String> tagIds;
  final String email;
  final String notes;

  /// 'import' (from Odoo) or 'manual' (added in the app).
  final String source;

  /// From Odoo: registered name, address parts and account balances.
  final String legalName;
  final String street;
  final String state;
  final String country;
  final double receivable;
  final double payable;
  final String currency;

  /// Odoo child contacts of this company.
  final List<ClientContact> contacts;

  /// Hidden by a KAM / manager: left out of lists, the map, plans, visits
  /// and statistics (e.g. clients that belong to no salesperson).
  final bool hidden;

  /// Who moved this client between sales executives, oldest first.
  final List<ClientTransfer> transfers;

  /// Clients marked "not duplicates" of this one (left out of the
  /// possible duplicates list).
  final List<String> notDuplicates;

  /// Clients merged into this one, with what they had absorbed before.
  final List<MergedClient> mergedFrom;

  /// Label of the main location ([lat], [lng]): a `settings/locationTypes`
  /// id such as 'office'; empty = unlabelled.
  final String mainLocationType;

  /// More places of the same client (factory, showroom, …), each labelled.
  /// Only kept while the client has a main location.
  final List<ClientLocation> extraLocations;

  final DateTime? createdAt;

  /// The main location. Imports, duplicates and plans use this one.
  bool get hasLocation => lat != null && lng != null;

  /// Every location, main first; empty without a main location.
  List<ClientLocation> get locations => [
        if (hasLocation)
          ClientLocation(id: ClientLocation.mainId, typeId: mainLocationType, lat: lat!, lng: lng!),
        if (hasLocation) ...extraLocations,
      ];

  static String normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  factory Client.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Client(
      id: doc.id,
      vat: d['vat'] as String? ?? '',
      nameKey: d['nameKey'] as String? ?? '',
      name: d['name'] as String? ?? '',
      aliases: List<String>.from(d['aliases'] as List? ?? const []),
      phone: d['phone'] as String? ?? '',
      mobile: d['mobile'] as String? ?? '',
      address: d['address'] as String? ?? '',
      city: d['city'] as String? ?? '',
      tags: d['tags'] as String? ?? '',
      odooSalesperson: d['odooSalesperson'] as String? ?? '',
      googlePin: d['googlePin'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      assignedTo: d['assignedTo'] as String?,
      category: switch (d['category']) { final String c when const ['A', 'B', 'C'].contains(c) => c, _ => 'B' },
      lastVisitAt: (d['lastVisitAt'] as Timestamp?)?.toDate(),
      contactPerson: d['contactPerson'] as String? ?? '',
      clientType: d['clientType'] as String? ?? '',
      companyId: d['companyId'] as String? ?? '',
      tagIds: List<String>.from(d['tagIds'] as List? ?? const []),
      email: d['email'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      source: d['source'] as String? ?? 'import',
      legalName: d['legalName'] as String? ?? '',
      street: d['street'] as String? ?? '',
      state: d['state'] as String? ?? '',
      country: d['country'] as String? ?? '',
      receivable: (d['receivable'] as num?)?.toDouble() ?? 0,
      payable: (d['payable'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] as String? ?? '',
      contacts: [
        for (final c in d['contacts'] as List? ?? const [])
          if (c is Map) ClientContact.fromMap(c),
      ],
      hidden: d['hidden'] == true,
      transfers: [
        for (final t in d['transfers'] as List? ?? const [])
          if (t is Map) ClientTransfer.fromMap(t),
      ],
      notDuplicates: List<String>.from(d['notDuplicates'] as List? ?? const []),
      mergedFrom: [
        for (final m in d['mergedFrom'] as List? ?? const [])
          if (m is Map) MergedClient.fromMap(m),
      ],
      mainLocationType: d['mainLocationType'] as String? ?? '',
      extraLocations: [
        for (final l in d['extraLocations'] as List? ?? const [])
          if (l is Map && l['lat'] is num && l['lng'] is num) ClientLocation.fromMap(l),
      ],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One place of a client. The main one is the client's own `lat` / `lng`
/// (id [mainId]); others are in `clients.extraLocations`.
class ClientLocation {
  const ClientLocation({
    required this.id,
    required this.typeId,
    required this.lat,
    required this.lng,
    this.address = '',
  });

  static const mainId = 'main';

  factory ClientLocation.fromMap(Map<dynamic, dynamic> m) => ClientLocation(
        id: m['id'] as String? ?? '',
        typeId: m['typeId'] as String? ?? '',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        address: m['address'] as String? ?? '',
      );

  final String id;

  /// `settings/locationTypes` id; empty = unlabelled.
  final String typeId;
  final double lat;
  final double lng;
  final String address;

  bool get isMain => id == mainId;

  ClientLocation copyWith({String? id, String? typeId, double? lat, double? lng, String? address}) => ClientLocation(
        id: id ?? this.id,
        typeId: typeId ?? this.typeId,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        address: address ?? this.address,
      );

  Map<String, dynamic> toMap() => {'id': id, 'typeId': typeId, 'lat': lat, 'lng': lng, 'address': address};
}

/// Great-circle distance in meters.
double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// The client's location closest to (lat, lng), or null when it has none.
ClientLocation? nearestLocation(Client client, double lat, double lng) {
  ClientLocation? best;
  var bestDistance = double.infinity;
  for (final l in client.locations) {
    final d = metersBetween(lat, lng, l.lat, l.lng);
    if (d < bestDistance) {
      best = l;
      bestDistance = d;
    }
  }
  return best;
}

/// Firestore fields for a client's whole location list: the first becomes
/// the main location (`lat`, `lng`, `mainLocationType`), the rest
/// `extraLocations`. An empty list removes all locations.
Map<String, dynamic> locationsUpdate(List<ClientLocation> list) {
  final main = list.firstOrNull;
  return {
    'lat': main?.lat,
    'lng': main?.lng,
    'mainLocationType': main?.typeId ?? '',
    'extraLocations': [
      for (final (i, l) in list.skip(1).indexed)
        (l.isMain ? l.copyWith(id: 'l${DateTime.now().millisecondsSinceEpoch}_$i') : l).toMap(),
    ],
  };
}

class ClientContact {
  const ClientContact({required this.name, required this.phone, required this.mobile});

  factory ClientContact.fromMap(Map<dynamic, dynamic> m) => ClientContact(
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        mobile: m['mobile'] as String? ?? '',
      );

  final String name;
  final String phone;
  final String mobile;

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'mobile': mobile};
}
