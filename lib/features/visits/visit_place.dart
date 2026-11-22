import '../../core/saudi_cities.dart';
import '../clients/client.dart';
import '../clients/client_tags.dart';
import 'visit.dart';

/// Where a visit was, for its row and page (2026-11-21, user: "show on the
/// visit where they have been visited"): the location's label, its address
/// when it has one and the city — "Showroom · Dammam". The city comes from
/// the location's pin, else the check-in position (older visits too).
/// Null for calls and when nothing is known.
String? visitPlace(Visit v, Client? client, Map<String, ClientTag> types, String lang) {
  if (v.isCall) return null;
  final loc = client?.allLocations.where((l) => l.id == v.locationId).firstOrNull;
  final lat = loc?.lat ?? v.checkInLat;
  final lng = loc?.lng ?? v.checkInLng;
  final type = types[v.locationTypeId]?.label(lang);
  final address = loc?.address.trim() ?? '';
  final city = lat == null || lng == null ? null : nearestSaudiCity(lat, lng)?.label(lang);
  final name = loc?.name.trim() ?? '';
  final parts = [
    if (type != null && type.isNotEmpty) type,
    if (name.isNotEmpty) name,
    if (address.isNotEmpty) address,
    if (city != null && !address.contains(city)) city,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
