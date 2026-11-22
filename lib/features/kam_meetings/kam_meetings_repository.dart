import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import '../notifications/notifications.dart';
import '../plan/plan_task.dart' show dayKey;
import 'kam_meeting.dart';

CollectionReference<Map<String, dynamic>> get _meetings => FirebaseFirestore.instance.collection('kam_meetings');
CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore.instance.collection('kam_tasks');

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// What the signed-in person reads: SM / GM everything, a KAM their own.
Query<Map<String, dynamic>>? _scoped(CollectionReference<Map<String, dynamic>> c, Ref ref) {
  final me = ref.watch(currentUserProvider).value;
  if (managesKamMeetings(me)) return c;
  if (seesKamMeetings(me)) return c.where('kamId', isEqualTo: me!.id);
  return null;
}

final kamMeetingsProvider = StreamProvider<List<KamMeeting>>((ref) {
  final q = _scoped(_meetings, ref);
  if (q == null) return Stream.value(const []);
  return q.snapshots().map((s) => s.docs.map(KamMeeting.fromDoc).toList());
});

final kamTasksProvider = StreamProvider<List<KamTask>>((ref) {
  final q = _scoped(_tasks, ref);
  if (q == null) return Stream.value(const []);
  return q.snapshots().map((s) => s.docs.map(KamTask.fromDoc).toList());
});

final kamMeetingProvider = Provider.family<KamMeeting?, String>((ref, id) {
  for (final m in ref.watch(kamMeetingsProvider).value ?? const <KamMeeting>[]) {
    if (m.id == id) return m;
  }
  return null;
});

final meetingTasksProvider = Provider.family<List<KamTask>, String>((ref, meetingId) => [
      for (final t in ref.watch(kamTasksProvider).value ?? const <KamTask>[])
        if (t.meetingId == meetingId) t,
    ]);

/// A task on the meeting form: [id] null = new.
typedef KamTaskDraft = ({String? id, String text, DateTime? due});

/// Adds ([id] null) or updates a meeting and its tasks: new drafts are
/// added, existing ones get their text / due day (done ones keep their
/// status), [removedTaskIds] are deleted. The KAM is told about a new
/// meeting and about tasks added later. Returns the meeting id.
Future<String> saveKamMeeting({
  String? id,
  required String kamId,
  required DateTime at,
  required String conclusion,
  required List<KamTaskDraft> tasks,
  Set<String> removedTaskIds = const {},
}) =>
    saving(() async {
      final batch = FirebaseFirestore.instance.batch();
      final doc = id == null ? _meetings.doc() : _meetings.doc(id);
      batch.set(
        doc,
        {
          'kamId': kamId,
          'at': Timestamp.fromDate(at),
          'conclusion': conclusion.trim(),
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
          if (id == null) ...{'createdBy': _uid, 'createdAt': FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
      var added = 0;
      for (final t in tasks) {
        final text = t.text.trim();
        if (text.isEmpty) continue;
        final due = t.due == null ? null : dayKey(t.due!);
        if (t.id == null) {
          added++;
          batch.set(_tasks.doc(), {
            'meetingId': doc.id,
            'kamId': kamId,
            'text': text,
            'due': due,
            'status': 'open',
            'comment': '',
            'createdBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(_tasks.doc(t.id), {'text': text, 'due': due, 'kamId': kamId});
        }
      }
      for (final r in removedTaskIds) {
        batch.delete(_tasks.doc(r));
      }
      await batch.commit();
      if (id == null || added > 0) {
        await sendNotifications(
          toIds: [kamId],
          type: NotificationType.kamMeeting,
          fromId: _uid,
          ownerId: kamId,
          date: dayKey(at),
          count: added,
          ref: doc.id,
          issue: id == null ? 'new' : 'tasks',
        );
      }
      return doc.id;
    });

/// Deletes a meeting and its tasks.
Future<void> deleteKamMeeting(String id) => saving(() async {
      final tasks = await _tasks.where('meetingId', isEqualTo: id).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final t in tasks.docs) {
        batch.delete(t.reference);
      }
      batch.delete(_meetings.doc(id));
      await batch.commit();
    });

/// The KAM marks a task done ([comment] required); whoever set the meeting
/// (else every SM / GM given in [notifyIds]) is told.
Future<void> markKamTaskDone(KamTask task, String comment, {required List<String> notifyIds}) => saving(() async {
      if (!validDoneComment(comment)) throw ArgumentError('A comment is required');
      await _tasks.doc(task.id).update({
        'status': 'done',
        'comment': comment.trim(),
        'doneAt': FieldValue.serverTimestamp(),
      });
      await sendNotifications(
        toIds: notifyIds,
        type: NotificationType.kamTaskDone,
        fromId: _uid,
        ownerId: task.kamId,
        date: dayKey(DateTime.now()),
        count: 1,
        ref: task.meetingId,
        clientName: task.text.length > 140 ? '${task.text.substring(0, 140)}…' : task.text,
        note: comment.trim().length > 140 ? '${comment.trim().substring(0, 140)}…' : comment.trim(),
      );
    });

/// SM / GM: back to open (the KAM's comment is kept until done again).
Future<void> reopenKamTask(KamTask task) =>
    saving(() => _tasks.doc(task.id).update({'status': 'open', 'doneAt': null}));
