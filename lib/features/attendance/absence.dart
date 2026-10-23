import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../notifications/notifications.dart';

// "I won't be at work" (user request 2026-10-22): someone who checks
// attendance tells the company before the day (today or tomorrow) with a
// reason. Firestore `absences/{uid}_{yyyy-MM-dd}` {uid, date, month, reason,
// note, status, createdAt; decided: decidedBy, decidedAt, comment, countAs,
// leaveRequestId}. Files (e.g. a medical report) in its `attachments`.
// The `absenceReported` Cloud Function tells their direct manager, HR and
// the GMs. HR or the GM decides (user decision 2026-10-22): rejected = an
// absence day (counted as missed); accepted = sick leave (only with a
// document attached) or annual leave, saved as an approved leave request
// so it uses their balance.

enum AbsenceReason {
  sick,
  tired,
  cantCome;

  static AbsenceReason fromKey(Object? key) => values.asNameMap()[key] ?? cantCome;
}

enum AbsenceStatus {
  pending,
  accepted,
  rejected;

  static AbsenceStatus fromKey(Object? key) => values.asNameMap()[key] ?? pending;
}

/// What an accepted absence counts as: a leave type id.
enum AbsenceLeave {
  sick('sick'),
  annual('annual');

  const AbsenceLeave(this.typeId);

  final String typeId;

  static AbsenceLeave? fromKey(Object? key) => values.where((v) => v.typeId == key).firstOrNull;
}

/// While there is no HR account, the sales manager acts as HR for reported
/// absences (user request 2026-10-22, to test): decides them and gets the
/// notifications. Turn off here, in firestore.rules (`decidesAbsences`) and
/// in functions/index.js (`SM_ACTS_AS_HR`) once HR has an account.
const smActsAsHr = true;

/// Who decides reported absences: HR and the GM (and the sales manager, see [smActsAsHr]).
bool decidesAbsences(UserRole role) =>
    role == UserRole.hr || role == UserRole.gm || (smActsAsHr && role == UserRole.salesManager);

class Absence {
  const Absence({
    required this.uid,
    required this.date,
    required this.reason,
    required this.note,
    this.status = AbsenceStatus.pending,
    this.countAs,
    this.comment = '',
    this.decidedBy,
    this.decidedAt,
    this.leaveRequestId,
    this.createdAt,
  });

  final String uid;

  /// 'yyyy-MM-dd'.
  final String date;
  final AbsenceReason reason;
  final String note;
  final AbsenceStatus status;

  /// Accepted as this leave.
  final AbsenceLeave? countAs;

  /// HR's / the GM's comment with the decision.
  final String comment;
  final String? decidedBy;
  final DateTime? decidedAt;

  /// Accepted: the approved leave request made for it.
  final String? leaveRequestId;
  final DateTime? createdAt;

  String get id => '${uid}_$date';
  bool get pending => status == AbsenceStatus.pending;

  factory Absence.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Absence(
      uid: d['uid'] as String? ?? '',
      date: d['date'] as String? ?? '',
      reason: AbsenceReason.fromKey(d['reason']),
      note: d['note'] as String? ?? '',
      status: AbsenceStatus.fromKey(d['status']),
      countAs: AbsenceLeave.fromKey(d['countAs']),
      comment: d['comment'] as String? ?? '',
      decidedBy: d['decidedBy'] as String?,
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      leaveRequestId: d['leaveRequestId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

final _absences = FirebaseFirestore.instance.collection('absences');

DocumentReference<Map<String, dynamic>> absenceDoc(String uid, String date) => _absences.doc('${uid}_$date');

Map<String, Absence> _byDate(QuerySnapshot<Map<String, dynamic>> s) =>
    {for (final d in s.docs) (d.data()['date'] as String? ?? ''): Absence.fromDoc(d)};

/// The signed-in person's reported absences, by date.
final myAbsencesProvider = StreamProvider<Map<String, Absence>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const {});
  return _absences.where('uid', isEqualTo: me.id).snapshots().map(_byDate);
});

final absenceProvider = StreamProvider.family<Absence?, String>(
    (ref, id) => _absences.doc(id).snapshots().map((s) => s.exists ? Absence.fromDoc(s) : null));

/// Everyone's reported absences on one day, by uid (Attendance page).
final dayAbsencesProvider = StreamProvider.family<Map<String, Absence>, String>((ref, day) => _absences
    .where('date', isEqualTo: day)
    .snapshots()
    .map((s) => {for (final d in s.docs) (d.data()['uid'] as String? ?? ''): Absence.fromDoc(d)}));

/// Everyone's reported absences in one month 'yyyy-MM' (monthly report).
final monthAbsencesProvider = StreamProvider.family<List<Absence>, String>((ref, month) => _absences
    .where('month', isEqualTo: month)
    .snapshots()
    .map((s) => [for (final d in s.docs) Absence.fromDoc(d)]));

/// Absences waiting for a decision (HR / GM Home), oldest day first.
final pendingAbsencesProvider = StreamProvider<List<Absence>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !decidesAbsences(me.role)) return Stream.value(const []);
  return _absences.where('status', isEqualTo: AbsenceStatus.pending.name).snapshots().map((s) {
    final list = [for (final d in s.docs) Absence.fromDoc(d)];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  });
});

/// Every reported absence, latest day first (HR area: a place to find them
/// besides the notifications, user request 2026-10-22).
final allAbsencesProvider = StreamProvider<List<Absence>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.role.canSeeHr) return Stream.value(const []);
  return _absences.orderBy('date', descending: true).limit(500).snapshots().map((s) => [for (final d in s.docs) Absence.fromDoc(d)]);
});

/// Saves [me]'s absence on [date], waiting for HR / the GM.
Future<void> reportAbsence({
  required AppUser me,
  required String date,
  required AbsenceReason reason,
  required String note,
}) => saving(() => absenceDoc(me.id, date).set({
      'uid': me.id,
      'date': date,
      'month': date.substring(0, 7),
      'reason': reason.name,
      'note': note,
      'status': AbsenceStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    }));

/// Takes back an absence still waiting (e.g. they came after all).
Future<void> withdrawAbsence(Absence a) => saving(() => absenceDoc(a.uid, a.date).delete());

/// HR / the GM decide: accepted as [countAs] leave (an approved leave
/// request for that day) or rejected (an absence day). Tells the person, and
/// on acceptance their direct manager, who is on leave.
Future<void> decideAbsence({
  required Absence absence,
  required AppUser me,
  required AppUser person,
  required AbsenceLeave? countAs,
  required String comment,
  required List<LeaveType> types,
  required Set<int> workDays,
  required Set<String> holidays,
  required List<AppUser> users,
}) => saving(() async {
  String? requestId;
  if (countAs != null) {
    final type = types.where((t) => t.id == countAs.typeId).firstOrNull ??
        LeaveType.defaults.firstWhere((t) => t.id == countAs.typeId);
    final day = DateTime.parse(absence.date);
    requestId = await LeaveRepository().recordAbsenceLeave(
      me: me,
      person: person,
      type: type,
      date: absence.date,
      days: leaveDays(from: day, to: day, calendarDays: type.calendarDays, workDays: workDays, holidays: holidays),
      reason: absence.note,
      comment: comment,
      absenceId: absence.id,
    );
  }
  await absenceDoc(absence.uid, absence.date).update({
    'status': (countAs == null ? AbsenceStatus.rejected : AbsenceStatus.accepted).name,
    'countAs': countAs?.typeId,
    'comment': comment,
    'decidedBy': me.id,
    'decidedAt': FieldValue.serverTimestamp(),
    'leaveRequestId': requestId,
  });
  await sendNotifications(
    toIds: [absence.uid],
    type: countAs == null ? NotificationType.absenceRejected : NotificationType.absenceAccepted,
    fromId: me.id,
    ownerId: absence.uid,
    date: absence.date,
    count: 0,
    ref: absence.id,
    issue: countAs?.typeId,
  );
  if (countAs != null) {
    await sendNotifications(
      toIds: [for (final id in directManagersOf(person, users)) if (id != absence.uid) id],
      type: NotificationType.teamOnLeave,
      fromId: me.id,
      ownerId: absence.uid,
      date: absence.date,
      count: 0,
      ref: requestId,
      note: absence.date,
    );
  }
});
