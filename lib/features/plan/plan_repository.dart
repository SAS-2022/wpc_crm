import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../visits/visit.dart';
import 'plan_task.dart';
import '../../core/saving.dart';

CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore.instance.collection('tasks');
CollectionReference<Map<String, dynamic>> get _visits => FirebaseFirestore.instance.collection('visits');

List<PlanTask> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
  final tasks = s.docs.map(PlanTask.fromDoc).toList();
  // Pending approval first, then open, then done.
  int rank(PlanTask t) => t.approval == TaskApproval.pending ? 0 : (t.done ? 2 : 1);
  tasks.sort((a, b) => rank(a).compareTo(rank(b)));
  return tasks;
}

/// One person's plan for one day: (userId, dayKey).
final dayTasksProvider = StreamProvider.family<List<PlanTask>, (String, String)>((ref, key) =>
    _tasks.where('ownerId', isEqualTo: key.$1).where('date', isEqualTo: key.$2).snapshots().map(_sorted));

/// One person's tasks for a month: (userId, monthKey).
final monthTasksProvider = StreamProvider.family<List<PlanTask>, (String, String)>((ref, key) =>
    _tasks.where('ownerId', isEqualTo: key.$1).where('month', isEqualTo: key.$2).snapshots().map(_sorted));

/// One person's visits for a month: (userId, monthKey).
final monthVisitsProvider = StreamProvider.family<List<Visit>, (String, String)>((ref, key) => _visits
    .where('salesExecId', isEqualTo: key.$1)
    .where('month', isEqualTo: key.$2)
    .snapshots()
    .map((s) => s.docs.map(Visit.fromDoc).toList()));

/// Everyone's tasks for a day (KAM / managers only).
final teamDayTasksProvider = StreamProvider.family<List<PlanTask>, String>((ref, day) =>
    _tasks.where('date', isEqualTo: day).snapshots().map(_sorted));

/// Everyone's visits for a month (KAM / managers only).
final teamMonthVisitsProvider = StreamProvider.family<List<Visit>, String>((ref, month) =>
    _visits.where('month', isEqualTo: month).snapshots().map((s) => s.docs.map(Visit.fromDoc).toList()));

/// Tasks waiting for approval (KAM / managers only).
final pendingTasksProvider = StreamProvider<List<PlanTask>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.role.isSupervisor) return Stream.value(const []);
  return _tasks.where('approval', isEqualTo: TaskApproval.pending.name).snapshots().map(_sorted);
});

/// The plan items a visit ticked, with their checklists: (visitId, ownerId).
final visitPlanTasksProvider = StreamProvider.family<List<PlanTask>, (String, String)>((ref, key) => _tasks
    .where('visitId', isEqualTo: key.$1)
    .where('ownerId', isEqualTo: key.$2)
    .snapshots()
    .map((s) => s.docs.map(PlanTask.fromDoc).toList()));

final planRepositoryProvider = Provider((ref) => PlanRepository());

class PlanRepository {
  /// Adds several client visits (or one free task) in one write. Each visit
  /// gets the [checklist] tasks.
  Future<void> addMany({
    required String ownerId,
    required String date,
    required String createdBy,
    required bool approved,
    required List<({String id, String name})> clients,
    String title = '',
    List<String> checklist = const [],
  }) => saving(() async {
    final batch = FirebaseFirestore.instance.batch();
    final items = clients.isEmpty ? [null] : clients;
    for (final c in items) {
      batch.set(_tasks.doc(), {
        'ownerId': ownerId,
        'date': date,
        'month': date.substring(0, 7),
        'clientId': c?.id,
        'clientName': c?.name,
        'title': title,
        'createdBy': createdBy,
        'approval': (approved ? TaskApproval.approved : TaskApproval.pending).name,
        'approvedBy': approved ? createdBy : null,
        'done': false,
        if (c != null && checklist.isNotEmpty)
          'checklist': [for (final text in checklist) ChecklistItem.create(text, createdBy).toMap()],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  });

  /// Approves every pending item of [tasks]; returns how many.
  Future<int> approveAll(List<PlanTask> tasks, String approverId) => saving(() async {
    final pending = tasks.where((t) => t.approval == TaskApproval.pending).toList();
    final batch = FirebaseFirestore.instance.batch();
    for (final t in pending) {
      batch.update(_tasks.doc(t.id), {
        'approval': TaskApproval.approved.name,
        'approvedBy': approverId,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return pending.length;
  });

  Future<void> setApproval(String taskId, TaskApproval approval, String approverId) => saving(() => _tasks.doc(taskId).update({
        'approval': approval.name,
        'approvedBy': approverId,
        'approvedAt': FieldValue.serverTimestamp(),
      }));

  Future<void> setDone(String taskId, bool done) => saving(() => _tasks.doc(taskId).update({
        'done': done,
        'doneAt': done ? FieldValue.serverTimestamp() : null,
      }));

  Future<void> delete(String taskId) => saving(() => _tasks.doc(taskId).delete());

  Future<void> setTitle(String taskId, String title) => saving(() => _tasks.doc(taskId).update({'title': title}));

  Future<void> setChecklist(String taskId, List<ChecklistItem> items) => saving(() =>
      _tasks.doc(taskId).update({'checklist': [for (final i in items) i.toMap()]}));

  /// Deletes [tasks] in one write.
  Future<void> deleteAll(List<PlanTask> tasks) => saving(() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final t in tasks) {
      batch.delete(_tasks.doc(t.id));
    }
    await batch.commit();
  });

  /// Ticks today's visit tasks for this client once the visit is saved.
  Future<void> completeVisitTasks({
    required String ownerId,
    required String clientId,
    required String visitId,
    required DateTime day,
  }) async {
    final open = await _tasks
        .where('ownerId', isEqualTo: ownerId)
        .where('date', isEqualTo: dayKey(day))
        .where('clientId', isEqualTo: clientId)
        .where('done', isEqualTo: false)
        .get();
    for (final d in open.docs) {
      await d.reference.update({'done': true, 'doneAt': FieldValue.serverTimestamp(), 'visitId': visitId});
    }
  }
}
