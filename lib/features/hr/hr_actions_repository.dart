import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'hr_actions.dart';

final _actions = FirebaseFirestore.instance.collection('hr_actions');

/// The latest 500 HR actions (HR area only; rules deny everyone else).
final allHrActionsProvider = StreamProvider<List<HrAction>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.can.canSeeHr) return Stream.value(const []);
  return _actions
      .orderBy('date', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => [for (final d in s.docs) HrAction.fromDoc(d)]);
});

/// One person's HR actions, newest first.
final personHrActionsProvider = StreamProvider.family<List<HrAction>, String>((ref, uid) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.can.canSeeHr) return Stream.value(const []);
  return _actions.where('uid', isEqualTo: uid).snapshots().map((s) {
    final list = [for (final d in s.docs) HrAction.fromDoc(d)];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  });
});

/// The signed-in employee's records waiting for "Agreed and Accepted",
/// oldest first (rules: own records that were sent).
final myPendingHrActionsProvider = StreamProvider<List<HrAction>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value?.id : null));
  if (uid == null) return Stream.value(const []);
  return _actions.where('uid', isEqualTo: uid).where('sent', isEqualTo: true).snapshots().map((s) {
    final list = [for (final d in s.docs) HrAction.fromDoc(d)]..retainWhere((a) => a.awaitingAcceptance);
    list.sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    return list;
  });
});

final hrActionProvider = StreamProvider.family<HrAction?, String>(
    (ref, id) => _actions.doc(id).snapshots().map((d) => d.exists ? HrAction.fromDoc(d) : null));

final hrActionsRepositoryProvider = Provider((ref) => HrActionsRepository());

class HrActionsRepository {
  /// Saves [a] (new when its id is empty); returns the id. [askAgain]: the
  /// employee had accepted it and the content changed — accept again.
  Future<String> save(HrAction a, String byId, {bool askAgain = false}) => saving(() async {
        final data = {
          ...a.toMap(),
          'updatedBy': byId,
          'updatedAt': FieldValue.serverTimestamp(),
          if (askAgain) 'acceptedAt': null,
        };
        if (a.id.isEmpty) {
          final doc = _actions.doc();
          await doc.set({
            ...data,
            'cancelled': false,
            'acceptedAt': null,
            'createdBy': byId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return doc.id;
        }
        await _actions.doc(a.id).update(data);
        return a.id;
      });

  /// The employee presses "Agreed and Accepted" (rules: only this field, once).
  Future<void> accept(String id) => saving(() => _actions.doc(id).update({'acceptedAt': FieldValue.serverTimestamp()}));

  /// Cancels (kept on record, doesn't count) or restores [id].
  Future<void> setCancelled(String id, bool cancelled, String note, String byId) => saving(() => _actions.doc(id).update({
        'cancelled': cancelled,
        'cancelNote': cancelled ? note : '',
        'cancelledBy': cancelled ? byId : null,
        'cancelledAt': cancelled ? FieldValue.serverTimestamp() : null,
      }));

  /// Deletes [id] with its attachment docs and files.
  Future<void> delete(String id) => saving(() async {
        final files = await _actions.doc(id).collection('attachments').get();
        for (final f in files.docs) {
          for (final key in ['storagePath', 'thumbPath']) {
            final path = f.data()[key] as String?;
            if (path != null && path.isNotEmpty) {
              await FirebaseStorage.instance.ref(path).delete().catchError((_) {});
            }
          }
          await f.reference.delete();
        }
        await _actions.doc(id).delete();
      });
}
