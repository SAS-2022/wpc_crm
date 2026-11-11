/// What every client must have before it is saved from the app (user
/// decision 2026-11-10): a name, a type (at least one client tag), a contact
/// person, a phone or mobile number and a location. Applies to new clients
/// and to edits on the edit screen; Odoo / sheet imports are not checked.
/// Firestore rules check the same on app-added clients (`hasRequiredFields`).
library;

enum RequiredClientField { name, type, contactPerson, phone, location }

/// The required fields missing from [data] (the edit screen's save map).
/// [hasOtherLocation]: the client keeps an extra location that becomes the
/// main one when the main coordinates are cleared.
List<RequiredClientField> missingClientFields(Map<String, dynamic> data, {bool hasOtherLocation = false}) {
  bool blank(String key) => ((data[key] as String?) ?? '').trim().isEmpty;
  final tags = data['tagIds'];
  return [
    if (blank('name')) RequiredClientField.name,
    if (tags is! List || tags.isEmpty) RequiredClientField.type,
    if (blank('contactPerson')) RequiredClientField.contactPerson,
    if (blank('phone') && blank('mobile')) RequiredClientField.phone,
    if (!hasOtherLocation && (data['lat'] is! num || data['lng'] is! num)) RequiredClientField.location,
  ];
}
