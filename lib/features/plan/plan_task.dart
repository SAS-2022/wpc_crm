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

  bool get isVisit => clientId != null;

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
    );
  }
}
