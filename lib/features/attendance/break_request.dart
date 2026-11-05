import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../notifications/notifications.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';

// Breaks (user request 2026-11-05): workers, operators and warehouse
// supervisors ([AppUser.requestsBreaks]) ask on the Home attendance card
// before leaving the site; their warehouse supervisor or department head
// approves on Home ([breakApproversOf]). A request not answered the same day
// is never carried to the next day (Home lists today's only; it shows as
// "not answered"). Leaving the site without an approved break shows as
// "Left without permission" on the Attendance page ([checkExits]); an
// approved break also gives its minutes on top of the away grace time before
// the day closes as "left the site" (both `deriveDay` copies).
// Firestore `break_requests/{uid}_{yyyy-MM-dd}_{ms}` {uid, date, month,
// minutes, reason, approverIds, status pending|approved|rejected, comment,
// decidedBy, decidedAt, createdAt}; the `breakRequestWritten` function copies
// them onto `attendance/{uid}_{date}.breaks`.

/// Lengths offered (minutes).
const breakMinuteChoices = [15, 30, 45, 60];

/// Who approves [person]'s breaks: their warehouse supervisor
/// (`supervisorId`, when active) and their department head(s)
/// ([departmentHeadsOf]); without a department head their direct managers.
List<String> breakApproversOf(AppUser person, List<AppUser> users) {
  final supervisor = [
    for (final u in users)
      if (u.id == person.supervisorId && u.active && u.id != person.id && u.role == UserRole.warehouseSupervisor) u.id,
  ];
  final heads = departmentHeadsOf(person, users);
  return {...supervisor, ...(heads.isEmpty ? directManagersOf(person, users) : heads)}.toList();
}

class BreakRequest {
  const BreakRequest({
    required this.id,
    required this.uid,
    required this.date,
    required this.minutes,
    required this.approverIds,
    this.reason = '',
    this.status = BreakStatus.pending,
    this.comment = '',
    this.decidedBy,
    this.decidedAt,
    this.createdAt,
  });

  final String id;
  final String uid;

  /// 'yyyy-MM-dd'.
  final String date;
  final int minutes;
  final String reason;
  final List<String> approverIds;
  final BreakStatus status;
  final String comment;
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  bool get pending => status == BreakStatus.pending;
  bool get approved => status == BreakStatus.approved;

  /// Still waiting after its day: not answered, never carried on.
  bool expiredOn(String today) => pending && date.compareTo(today) < 0;

  factory BreakRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return BreakRequest(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      date: d['date'] as String? ?? '',
      minutes: (d['minutes'] as num?)?.toInt() ?? 0,
      reason: d['reason'] as String? ?? '',
      approverIds: List<String>.from(d['approverIds'] as List? ?? const []),
      status: BreakStatus.fromKey(d['status']),
      comment: d['comment'] as String? ?? '',
      decidedBy: d['decidedBy'] as String?,
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

final _requests = FirebaseFirestore.instance.collection('break_requests');

/// The signed-in person's requests today, oldest first.
final myBreaksTodayProvider = StreamProvider<List<BreakRequest>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _requests
      .where('uid', isEqualTo: uid)
      .where('date', isEqualTo: attendanceDay(DateTime.now()))
      .snapshots()
      .map((s) => [for (final d in s.docs) BreakRequest.fromDoc(d)]
        ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now())));
});

/// Today's requests waiting for the signed-in approver, oldest first (only
/// array-contains, no composite index; status and day filtered here, so
/// yesterday's unanswered ones drop off).
final breaksToDecideProvider = StreamProvider<List<BreakRequest>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _requests.where('approverIds', arrayContains: uid).snapshots().map((s) {
    final today = attendanceDay(DateTime.now());
    final list = [
      for (final d in s.docs)
        if (BreakRequest.fromDoc(d) case final r when r.pending && r.date == today) r,
    ];
    list.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
    return list;
  });
});

/// [me] asks [approverIds] for a break of [minutes] now.
Future<void> askBreak({
  required AppUser me,
  required List<String> approverIds,
  required int minutes,
  String reason = '',
}) => saving(() async {
  final now = DateTime.now();
  final date = attendanceDay(now);
  final doc = _requests.doc('${me.id}_${date}_${now.millisecondsSinceEpoch}');
  await doc.set({
    'uid': me.id,
    'date': date,
    'month': date.substring(0, 7),
    'minutes': minutes,
    'reason': reason,
    'approverIds': approverIds,
    'status': BreakStatus.pending.name,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await sendNotifications(
    toIds: approverIds,
    type: NotificationType.breakRequested,
    fromId: me.id,
    ownerId: me.id,
    date: date,
    count: minutes,
    ref: doc.id,
    note: reason.isEmpty ? null : reason,
  );
});

/// Takes back a request still waiting.
Future<void> cancelBreak(BreakRequest r) => saving(() => _requests.doc(r.id).delete());

/// An approver approves or rejects; the person is told.
Future<void> decideBreak(BreakRequest r, AppUser me, {required bool approve, String comment = ''}) =>
    saving(() async {
      await _requests.doc(r.id).update({
        'status': (approve ? BreakStatus.approved : BreakStatus.rejected).name,
        'comment': comment,
        'decidedBy': me.id,
        'decidedAt': FieldValue.serverTimestamp(),
      });
      await sendNotifications(
        toIds: [r.uid],
        type: approve ? NotificationType.breakApproved : NotificationType.breakRejected,
        fromId: me.id,
        ownerId: r.uid,
        date: r.date,
        count: r.minutes,
        ref: r.id,
        note: comment.isEmpty ? null : comment,
      );
    });
