import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/providers.dart';
import '../clients/client.dart';
import '../clients/given_items.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_task.dart';
import 'app_calls.dart';
import 'visit.dart';

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
  /// [location]: which of the client's locations the visit is at (distance
  /// is measured to it); null = the main one. Returns the new visit's id.
  Future<String> add({
    required Client client,
    required String userId,
    required Position position,
    required String notes,
    required bool setClientLocation,
    ClientLocation? location,
    Map<GivenItem, int> given = const {},
  }) async {
    final at = location ?? client.locations.firstOrNull;
    final distance =
        at == null ? null : Geolocator.distanceBetween(position.latitude, position.longitude, at.lat, at.lng);
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
      if (at != null) 'locationId': at.id,
      if (at != null) 'locationTypeId': at.typeId,
      'notes': notes,
      'status': 'completed',
      if (given.isNotEmpty) 'given': {for (final e in given.entries) e.key.name: e.value},
    });
    batch.update(_db.collection('clients').doc(client.id), {
      'lastVisitAt': FieldValue.serverTimestamp(),
      ...givenClientUpdate(given),
      if (setClientLocation) 'lat': position.latitude,
      if (setClientLocation) 'lng': position.longitude,
    });
    await batch.commit();
    await _completePlan(userId, client.id, visitRef.id, now);
    return visitRef.id;
  }

  /// Saves a phone call with the client. It counts like a visit (the client
  /// turns green, today's plan item for the client is done) but has no
  /// position. [appCall]: the call was dialled from the app, with its length.
  Future<String> addCall({
    required Client client,
    required String userId,
    required String notes,
    AppCall? appCall,
  }) async {
    final now = DateTime.now();
    final visitRef = _db.collection('visits').doc();
    final batch = _db.batch();
    batch.set(visitRef, {
      'type': VisitType.call.name,
      'month': monthKey(now),
      'clientId': client.id,
      'clientName': client.name,
      'salesExecId': userId,
      'checkedInAt': FieldValue.serverTimestamp(),
      'notes': notes,
      'status': 'completed',
      'callFromApp': appCall != null,
      if (appCall != null) 'callSeconds': appCall.seconds,
      if (appCall != null) 'callStartedAt': Timestamp.fromDate(appCall.startedAt),
    });
    batch.update(_db.collection('clients').doc(client.id), {'lastVisitAt': FieldValue.serverTimestamp()});
    await batch.commit();
    await _completePlan(userId, client.id, visitRef.id, now);
    return visitRef.id;
  }

  Future<void> _completePlan(String userId, String clientId, String visitId, DateTime day) async {
    try {
      await PlanRepository().completeVisitTasks(ownerId: userId, clientId: clientId, visitId: visitId, day: day);
    } catch (_) {
      // The visit is saved; a failed plan update must not fail the visit.
    }
  }

  /// Sales manager / GM: deletes a visit (e.g. a test). Plan items it ticked
  /// are open again and the client's last visit is taken from the visits
  /// left. Comments, photos and files go with it (`cleanDeletedVisit` Cloud
  /// Function).
  Future<void> delete(Visit visit) async {
    await _db.collection('visits').doc(visit.id).delete();
    final ticked = await _db.collection('tasks').where('visitId', isEqualTo: visit.id).get();
    for (final t in ticked.docs) {
      await t.reference.update({'done': false, 'doneAt': null, 'visitId': null});
    }
    final left = await _db.collection('visits').where('clientId', isEqualTo: visit.clientId).get();
    final latest = left.docs
        .map((d) => d.data()['checkedInAt'])
        .whereType<Timestamp>()
        .fold<Timestamp?>(null, (a, b) => a == null || b.compareTo(a) > 0 ? b : a);
    await _db.collection('clients').doc(visit.clientId).update({
      'lastVisitAt': latest,
      // Catalogs / stands from the visits left.
      if (visit.given.isNotEmpty)
        'given': givenFromVisits(left.docs.map((d) => (
              at: (d.data()['checkedInAt'] as Timestamp?)?.toDate(),
              given: parseGiven(d.data()['given']),
            ))),
    });
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
