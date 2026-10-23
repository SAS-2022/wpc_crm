import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';

/// Where people check in (user request 2026-10-19): `work_sites/{id}`
/// {name, lat, lng, radius, active}. The sales manager / GM create them on a
/// map and assign people (`users.workSiteIds`).
class WorkSite {
  const WorkSite({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = defaultSiteRadius,
    this.active = true,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Meters around the point that count as "at the site".
  final double radius;
  final bool active;

  factory WorkSite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return WorkSite(
      id: doc.id,
      name: d['name'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      radius: (d['radius'] as num?)?.toDouble() ?? defaultSiteRadius,
      active: d['active'] != false,
    );
  }

  Map<String, Object> toMap() => {'name': name, 'lat': lat, 'lng': lng, 'radius': radius, 'active': active};
}

/// 100 m (user's spec); the phones' geofences need at least about this much.
const defaultSiteRadius = 100.0;

CollectionReference<Map<String, dynamic>> get _sites => FirebaseFirestore.instance.collection('work_sites');

/// Only active users may read work sites: signed out or waiting for
/// approval gives none (the listener used to start at app launch, before
/// sign-in, fail with permission-denied and stay failed after signing in).
final workSitesProvider = StreamProvider<List<WorkSite>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _sites.snapshots().map(
        (s) => s.docs.map(WorkSite.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)),
      );
});

/// Adds ([id] null) or updates a site; returns its id.
Future<String> saveWorkSite(WorkSite site, {String? id}) => saving(() async {
      final ref = id == null ? _sites.doc() : _sites.doc(id);
      await ref.set(site.toMap());
      return ref.id;
    });

Future<void> deleteWorkSite(String id) => saving(() => _sites.doc(id).delete());

/// Sets who works at [siteId]: adds it to [assign]'s sites, removes it from
/// [unassign]'s.
Future<void> assignWorkSite(String siteId, {required List<String> assign, required List<String> unassign}) =>
    saving(() async {
      final batch = FirebaseFirestore.instance.batch();
      final users = FirebaseFirestore.instance.collection('users');
      for (final uid in assign) {
        batch.update(users.doc(uid), {'workSiteIds': FieldValue.arrayUnion([siteId])});
      }
      for (final uid in unassign) {
        batch.update(users.doc(uid), {'workSiteIds': FieldValue.arrayRemove([siteId])});
      }
      await batch.commit();
    });
