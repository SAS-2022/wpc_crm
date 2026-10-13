import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get hasLocation => lat != null && lng != null;

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
    );
  }
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
