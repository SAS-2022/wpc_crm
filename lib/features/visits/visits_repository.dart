import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import '../clients/client.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_task.dart';
import 'visit.dart';

/// Check-ins farther than this from the client are flagged.
const visitRadiusMeters = 300.0;

/// Visits of one client, newest first. Sales execs only see their own.
final clientVisitsProvider = StreamProvider.family<List<Visit>, String>((ref, clientId) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  var query = FirebaseFirestore.instance.collection('visits').where('clientId', isEqualTo: clientId);
  if (!me.role.isSupervisor) query = query.where('salesExecId', isEqualTo: me.id);
  return query.snapshots().map(_newestFirst);
});

List<Visit> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) {
  final visits = s.docs.map(Visit.fromDoc).toList();
  final pending = DateTime.now();
  visits.sort((a, b) => (b.checkedInAt ?? pending).compareTo(a.checkedInAt ?? pending));
  return visits;
}

/// Visits list: own visits for sales execs, the latest 500 for KAM / managers.
final visitsProvider = StreamProvider<List<Visit>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final visits = FirebaseFirestore.instance.collection('visits');
  final query = me.role.isSupervisor
      ? visits.orderBy('checkedInAt', descending: true).limit(500)
      : visits.where('salesExecId', isEqualTo: me.id);
  return query.snapshots().map(_newestFirst);
});

final visitProvider = StreamProvider.family<Visit?, String>((ref, id) => FirebaseFirestore.instance
    .collection('visits')
    .doc(id)
    .snapshots()
    .map((s) => s.exists ? Visit.fromDoc(s) : null));

final visitCommentsProvider = StreamProvider.family<List<VisitComment>, String>((ref, visitId) =>
    FirebaseFirestore.instance
        .collection('visits')
        .doc(visitId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(VisitComment.fromDoc).toList()));

final visitsRepositoryProvider = Provider((ref) => VisitsRepository());

class VisitsRepository {
  final _db = FirebaseFirestore.instance;

  /// Saves the visit and marks the client visited (its marker turns green).
  /// With [setClientLocation], the check-in position becomes the client's location.
  /// Returns the new visit's id.
  Future<String> add({
    required Client client,
    required String userId,
    required Position position,
    required String notes,
    required bool setClientLocation,
  }) async {
    final distance = client.hasLocation
        ? Geolocator.distanceBetween(position.latitude, position.longitude, client.lat!, client.lng!)
        : null;
    final now = DateTime.now();
    final visitRef = _db.collection('visits').doc();
    final batch = _db.batch();
    batch.set(visitRef, {
      'month': monthKey(now),
      'clientId': client.id,
      'clientName': client.name,
      'salesExecId': userId,
      'checkedInAt': FieldValue.serverTimestamp(),
      'checkInLat': position.latitude,
      'checkInLng': position.longitude,
      'accuracy': position.accuracy,
      'mocked': position.isMocked,
      'distanceMeters': distance,
      'notes': notes,
      'status': 'completed',
    });
    batch.update(_db.collection('clients').doc(client.id), {
      'lastVisitAt': FieldValue.serverTimestamp(),
      if (setClientLocation) 'lat': position.latitude,
      if (setClientLocation) 'lng': position.longitude,
    });
    await batch.commit();
    try {
      await PlanRepository().completeVisitTasks(
        ownerId: userId,
        clientId: client.id,
        visitId: visitRef.id,
        day: now,
      );
    } catch (_) {
      // The visit is saved; a failed plan update must not fail the visit.
    }
    return visitRef.id;
  }

  /// A KAM marks that they were at the visit (or removes the mark with null).
  Future<void> setKam(String visitId, String? kamId) =>
      _db.collection('visits').doc(visitId).update({
        'kamId': kamId,
        'kamMarkedAt': kamId == null ? null : FieldValue.serverTimestamp(),
      });

  Future<void> addComment(String visitId, String authorId, String body) =>
      _db.collection('visits').doc(visitId).collection('comments').add({
        'authorId': authorId,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
