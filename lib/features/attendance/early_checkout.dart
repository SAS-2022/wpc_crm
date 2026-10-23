import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../notifications/notifications.dart';
import '../tracking/work_hours.dart';
import 'attendance_repository.dart';

// Leaving early (user request 2026-10-23): anyone may check in at any time,
// but checking out before the end of their work day needs their direct
// manager's approval ([directManagersOf]). The person asks on the
// attendance card with a reason; one of the managers approves or rejects
// (Home card); once approved the Check out button works for the rest of
// that day and the check-out time is when they press it (user decision).
// Firestore `checkout_requests/{uid}_{yyyy-MM-dd}` {uid, date, month,
// reason, approverIds, status pending|approved|rejected, comment,
// decidedBy, decidedAt, createdAt}. App-side only: automatic check-outs
// (leaving the site, end of day) are unchanged.

enum EarlyCheckoutStatus {
  pending,
  approved,
  rejected;

  static EarlyCheckoutStatus fromKey(Object? key) => values.asNameMap()[key] ?? pending;
}

/// Whether checking out at [now] needs approval: on one of [hours]' work
/// days before its end (Saudi time). Days off and after the end: no.
bool needsEarlyCheckoutApproval(DateTime now, WorkHours hours) {
  final t = WorkHours.saudiTime(now);
  return hours.days.contains(t.weekday) && t.hour * 60 + t.minute < hours.endMinute;
}

class EarlyCheckout {
  const EarlyCheckout({
    required this.uid,
    required this.date,
    required this.reason,
    required this.approverIds,
    this.status = EarlyCheckoutStatus.pending,
    this.comment = '',
    this.decidedBy,
    this.decidedAt,
    this.createdAt,
  });

  final String uid;

  /// 'yyyy-MM-dd'.
  final String date;
  final String reason;

  /// The direct managers asked; any one of them decides.
  final List<String> approverIds;
  final EarlyCheckoutStatus status;

  /// The manager's comment with the decision.
  final String comment;
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  String get id => '${uid}_$date';
  bool get pending => status == EarlyCheckoutStatus.pending;
  bool get approved => status == EarlyCheckoutStatus.approved;

  factory EarlyCheckout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return EarlyCheckout(
      uid: d['uid'] as String? ?? '',
      date: d['date'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      approverIds: List<String>.from(d['approverIds'] as List? ?? const []),
      status: EarlyCheckoutStatus.fromKey(d['status']),
      comment: d['comment'] as String? ?? '',
      decidedBy: d['decidedBy'] as String?,
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

final _requests = FirebaseFirestore.instance.collection('checkout_requests');

/// The signed-in person's request for today, if any.
final myEarlyCheckoutTodayProvider = StreamProvider<EarlyCheckout?>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(null);
  return _requests
      .doc('${uid}_${attendanceDay(DateTime.now())}')
      .snapshots()
      .map((s) => s.exists ? EarlyCheckout.fromDoc(s) : null);
});

/// Today's requests waiting for the signed-in manager, oldest first.
/// Only array-contains (no composite index); status and day filtered here.
final earlyCheckoutsToDecideProvider = StreamProvider<List<EarlyCheckout>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _requests.where('approverIds', arrayContains: uid).snapshots().map((s) {
    final today = attendanceDay(DateTime.now());
    final list = [
      for (final d in s.docs)
        if (EarlyCheckout.fromDoc(d) case final r when r.pending && r.date == today) r,
    ];
    list.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
    return list;
  });
});

/// [me] asks [approverIds] to leave early today; asking again after a
/// rejection replaces the old request.
Future<void> askEarlyCheckout({
  required AppUser me,
  required List<String> approverIds,
  required String reason,
}) => saving(() async {
  final date = attendanceDay(DateTime.now());
  final doc = _requests.doc('${me.id}_$date');
  await doc.set({
    'uid': me.id,
    'date': date,
    'month': date.substring(0, 7),
    'reason': reason,
    'approverIds': approverIds,
    'status': EarlyCheckoutStatus.pending.name,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await sendNotifications(
    toIds: approverIds,
    type: NotificationType.earlyCheckoutRequested,
    fromId: me.id,
    ownerId: me.id,
    date: date,
    count: 0,
    ref: doc.id,
    note: reason,
  );
});

/// Takes back a request still waiting.
Future<void> cancelEarlyCheckout(EarlyCheckout r) => saving(() => _requests.doc(r.id).delete());

/// A direct manager approves or rejects; the person is told.
Future<void> decideEarlyCheckout(EarlyCheckout r, AppUser me, {required bool approve, String comment = ''}) =>
    saving(() async {
      await _requests.doc(r.id).update({
        'status': (approve ? EarlyCheckoutStatus.approved : EarlyCheckoutStatus.rejected).name,
        'comment': comment,
        'decidedBy': me.id,
        'decidedAt': FieldValue.serverTimestamp(),
      });
      await sendNotifications(
        toIds: [r.uid],
        type: approve ? NotificationType.earlyCheckoutApproved : NotificationType.earlyCheckoutRejected,
        fromId: me.id,
        ownerId: r.uid,
        date: r.date,
        count: 0,
        ref: r.id,
        note: comment.isEmpty ? null : comment,
      );
    });
