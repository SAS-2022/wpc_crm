import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../users/user_log.dart';
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
    this.shortName = '',
    this.companyId,
    this.kind = SiteKind.office,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// Meters around the point that count as "at the site".
  final double radius;
  final bool active;

  /// Label on the map filter chips (user 2026-11-11); '' = made from the name.
  final String shortName;

  /// The company the site belongs to (picking a company on the maps narrows
  /// the sites to its own); null = none.
  final String? companyId;

  /// What the place is; sets its icon on the maps (user 2026-11-12).
  final SiteKind kind;

  factory WorkSite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return WorkSite(
      id: doc.id,
      name: d['name'] as String? ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      radius: (d['radius'] as num?)?.toDouble() ?? defaultSiteRadius,
      active: d['active'] != false,
      shortName: d['shortName'] as String? ?? '',
      companyId: (d['companyId'] as String?)?.isEmpty ?? true ? null : d['companyId'] as String,
      kind: SiteKind.fromValue(d['kind'] as String?),
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'radius': radius,
    'active': active,
    'shortName': shortName,
    'companyId': companyId,
    'kind': kind.name,
  };
}

/// Kind of work site (2026-11-12): its icon on every map. Missing = office.
enum SiteKind {
  office,
  warehouse,
  showroom,
  factory;

  static SiteKind fromValue(String? v) => values.where((k) => k.name == v).firstOrNull ?? office;
}

/// 100 m (user's spec); the phones' geofences need at least about this much.
const defaultSiteRadius = 100.0;

/// Radius choices in the site editor (25–75 m added 2026-11-12, user).
const siteRadiusSteps = [25.0, 50.0, 75.0, 100.0, 150.0, 200.0, 250.0, 300.0, 350.0, 400.0, 450.0, 500.0];

/// The OS geofence never goes below this (Android / iOS miss smaller
/// circles); arrivals are then confirmed by GPS against the real radius.
const minGeofenceRadius = 100.0;

/// Index in [siteRadiusSteps] nearest to [radius].
int siteRadiusStep(double radius) {
  var best = 0;
  for (var i = 1; i < siteRadiusSteps.length; i++) {
    if ((siteRadiusSteps[i] - radius).abs() < (siteRadiusSteps[best] - radius).abs()) best = i;
  }
  return best;
}

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
        batch.update(users.doc(uid), {'workSiteIds': FieldValue.arrayUnion([siteId]), ...userChangeStamp()});
      }
      for (final uid in unassign) {
        batch.update(users.doc(uid), {'workSiteIds': FieldValue.arrayRemove([siteId]), ...userChangeStamp()});
      }
      await batch.commit();
    });
