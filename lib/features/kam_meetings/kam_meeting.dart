import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';

// KAM meetings (2026-11-22, user): the sales manager meets each KAM weekly,
// writes the meeting's conclusion, sets the meeting time and gives the KAM
// tasks. The KAM sees their tasks and marks each done with a comment
// (required). Firestore `kam_meetings/{id}` {kamId, at, conclusion,
// createdBy, createdAt, updatedBy, updatedAt} and `kam_tasks/{id}`
// {meetingId, kamId, text, due 'yyyy-MM-dd'?, status open|done, comment,
// doneAt, createdBy, createdAt}. Rules: SM / GM write; the KAM reads their
// own and may only mark an open task done with a comment.

/// SM / GM hold the meetings and set tasks.
bool managesKamMeetings(AppUser? me) => me != null && me.active && me.can.isAdmin;

/// The page: SM / GM, and KAMs (their own meetings and tasks).
bool seesKamMeetings(AppUser? me) => managesKamMeetings(me) || (me != null && me.active && me.hasRole(UserRole.kam));

class KamMeeting {
  const KamMeeting({
    required this.id,
    required this.kamId,
    required this.at,
    this.conclusion = '',
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory KamMeeting.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return KamMeeting(
      id: doc.id,
      kamId: d['kamId'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
      conclusion: d['conclusion'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String kamId;

  /// Meeting time; null only while the server time is pending.
  final DateTime? at;
  final String conclusion;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool isUpcoming(DateTime now) => at != null && at!.isAfter(now);
}

enum KamTaskStatus { open, done }

class KamTask {
  const KamTask({
    required this.id,
    required this.meetingId,
    required this.kamId,
    required this.text,
    this.due,
    this.status = KamTaskStatus.open,
    this.comment = '',
    this.doneAt,
    this.createdAt,
  });

  factory KamTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return KamTask(
      id: doc.id,
      meetingId: d['meetingId'] as String? ?? '',
      kamId: d['kamId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      due: DateTime.tryParse(d['due'] as String? ?? ''),
      status: d['status'] == 'done' ? KamTaskStatus.done : KamTaskStatus.open,
      comment: d['comment'] as String? ?? '',
      doneAt: (d['doneAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String meetingId;
  final String kamId;
  final String text;

  /// Day it should be done by (optional).
  final DateTime? due;
  final KamTaskStatus status;

  /// The KAM's comment when marking it done (required then).
  final String comment;
  final DateTime? doneAt;
  final DateTime? createdAt;

  bool get done => status == KamTaskStatus.done;

  /// Open and past its due day.
  bool overdue(DateTime now) =>
      !done && due != null && DateTime(due!.year, due!.month, due!.day + 1).isBefore(now.add(const Duration(seconds: 1)));
}

/// Open tasks first (overdue, then by due day, no due day last, then
/// oldest), then done ones newest first.
List<KamTask> sortKamTasks(Iterable<KamTask> tasks, DateTime now) {
  int openOrder(KamTask a, KamTask b) {
    final o = (b.overdue(now) ? 1 : 0) - (a.overdue(now) ? 1 : 0);
    if (o != 0) return o;
    if (a.due != null && b.due != null) {
      final c = a.due!.compareTo(b.due!);
      if (c != 0) return c;
    } else if (a.due != null || b.due != null) {
      return a.due != null ? -1 : 1;
    }
    return (a.createdAt ?? now).compareTo(b.createdAt ?? now);
  }

  final open = tasks.where((t) => !t.done).toList()..sort(openOrder);
  final done = tasks.where((t) => t.done).toList()
    ..sort((a, b) => (b.doneAt ?? now).compareTo(a.doneAt ?? now));
  return [...open, ...done];
}

/// Upcoming meetings soonest first, then past ones newest first.
List<KamMeeting> sortKamMeetings(Iterable<KamMeeting> meetings, DateTime now) {
  final upcoming = meetings.where((m) => m.isUpcoming(now)).toList()..sort((a, b) => a.at!.compareTo(b.at!));
  final past = meetings.where((m) => !m.isUpcoming(now)).toList()
    ..sort((a, b) => (b.at ?? now).compareTo(a.at ?? now));
  return [...upcoming, ...past];
}

/// A done comment must say something.
bool validDoneComment(String comment) => comment.trim().isNotEmpty;
