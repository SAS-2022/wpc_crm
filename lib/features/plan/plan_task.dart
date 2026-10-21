import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// "2026-10-12": the day a task is planned for.
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// "2026-10": used to query a month without a composite index.
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

enum TaskApproval { pending, approved, rejected }

/// One item of a person's daily plan: a client visit (done automatically when
/// the visit is saved) or a free task (ticked by hand). Tasks added by the
/// sales executive wait for approval; tasks added by a KAM / manager don't.
class PlanTask {
  const PlanTask({
    required this.id,
    required this.ownerId,
    required this.date,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.createdBy,
    required this.approval,
    required this.done,
    required this.visitId,
    this.checklist = const [],
    this.locationId,
  });

  final String id;

  /// Whose plan this is.
  final String ownerId;
  final String date;
  final String? clientId;
  final String? clientName;

  /// Free-task text, or an optional note on a visit task.
  final String title;
  final String createdBy;
  final TaskApproval approval;
  final bool done;
  final String? visitId;

  /// Tasks to do at a client visit, ticked by the owner.
  final List<ChecklistItem> checklist;

  /// Which of the client's locations was picked when planning (2026-10-21);
  /// null or no longer there = the main one ([planStop]).
  final String? locationId;

  bool get isVisit => clientId != null;

  int get checklistDone => checklist.where((i) => i.done).length;

  factory PlanTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PlanTask(
      id: doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      date: d['date'] as String? ?? '',
      clientId: d['clientId'] as String?,
      clientName: d['clientName'] as String?,
      title: d['title'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      approval: TaskApproval.values.asNameMap()[d['approval']] ?? TaskApproval.pending,
      done: d['done'] as bool? ?? false,
      visitId: d['visitId'] as String?,
      locationId: d['locationId'] as String?,
      checklist: [
        for (final i in d['checklist'] as List<dynamic>? ?? const [])
          if (i is Map<String, dynamic>) ChecklistItem.fromMap(i),
      ],
    );
  }
}

/// One task on a planned client visit (e.g. "Collect payment"), added by a
/// KAM / manager or the owner and ticked by the owner, with an optional
/// comment. Stored in the plan item's `checklist` array.
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    required this.addedBy,
    this.done = false,
    this.comment = '',
    this.doneAt,
  });

  /// Random id: items are matched by it when one is ticked or removed.
  final String id;
  final String text;
  final String addedBy;
  final bool done;
  final String comment;
  final DateTime? doneAt;

  factory ChecklistItem.create(String text, String addedBy) =>
      ChecklistItem(id: FirebaseFirestore.instance.collection('tasks').doc().id, text: text, addedBy: addedBy);

  ChecklistItem complete({required bool done, String? comment}) => ChecklistItem(
        id: id,
        text: text,
        addedBy: addedBy,
        done: done,
        comment: comment ?? this.comment,
        doneAt: done ? (this.done ? doneAt : DateTime.now()) : null,
      );

  factory ChecklistItem.fromMap(Map<String, dynamic> d) => ChecklistItem(
        id: d['id'] as String? ?? '',
        text: d['text'] as String? ?? '',
        addedBy: d['addedBy'] as String? ?? '',
        done: d['done'] as bool? ?? false,
        comment: d['comment'] as String? ?? '',
        doneAt: (d['doneAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'addedBy': addedBy,
        'done': done,
        'comment': comment,
        // Server timestamps aren't allowed inside arrays.
        'doneAt': doneAt == null ? null : Timestamp.fromDate(doneAt!),
      };
}

/// Checklist texts used in [tasks], most used first: offered as quick choices.
List<String> recentChecklistTexts(Iterable<PlanTask> tasks) {
  final counts = <String, int>{};
  for (final t in tasks) {
    for (final i in t.checklist) {
      counts.update(i.text, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return (counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!)));
}
