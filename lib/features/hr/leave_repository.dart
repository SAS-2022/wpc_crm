import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../attachments/attachments.dart';
import '../notifications/notifications.dart';
import 'leave_rules.dart';
import '../../core/saving.dart';

/// A leave or other employee request in Firestore `leave_requests`. The type's
/// names are copied in, so history reads right after HR renames a type.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.uid,
    required this.typeId,
    required this.typeEn,
    required this.typeAr,
    required this.isLeave,
    required this.from,
    required this.to,
    required this.halfDay,
    this.travelDay,
    this.departureTime,
    required this.days,
    required this.year,
    required this.reason,
    required this.status,
    required this.steps,
    required this.stepIndex,
    required this.awaitingKey,
    required this.createdAt,
    this.watcherIds = const [],
  });

  final String id;

  /// Who asked.
  final String uid;
  final String typeId;
  final String typeEn;
  final String typeAr;
  final bool isLeave;

  /// 'yyyy-MM-dd'; null for requests without dates.
  final String? from;
  final String? to;
  final bool halfDay;

  /// 'yyyy-MM-dd' + 'HH:mm': the departure the person gave for the first
  /// day picked (2026-10-31). At or after the end of their work day, [from]
  /// is the next work day; otherwise [from] is this day.
  final String? travelDay;
  final String? departureTime;
  final double days;
  final int year;
  final String reason;
  final LeaveStatus status;
  final List<ApprovalStep> steps;
  final int stepIndex;

  /// Who may act now ('uid:…' / 'role:…'); null once decided or cancelled.
  final String? awaitingKey;
  final DateTime? createdAt;

  /// Told of every step without approving ([leaveWatchers], 2026-10-30).
  final List<String> watcherIds;

  String typeName(String lang) => lang == 'ar' && typeAr.isNotEmpty ? typeAr : typeEn;

  ApprovalStep? get currentStep => status == LeaveStatus.pending && stepIndex < steps.length ? steps[stepIndex] : null;

  LeaveUse get use => (typeId: typeId, year: year, from: from, days: days, status: status);

  factory LeaveRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LeaveRequest(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      typeId: d['typeId'] as String? ?? '',
      typeEn: d['typeEn'] as String? ?? '',
      typeAr: d['typeAr'] as String? ?? '',
      isLeave: d['isLeave'] as bool? ?? true,
      from: d['from'] as String?,
      to: d['to'] as String?,
      halfDay: d['halfDay'] as bool? ?? false,
      travelDay: d['travelDay'] as String?,
      departureTime: d['departureTime'] as String?,
      days: (d['days'] as num?)?.toDouble() ?? 0,
      year: (d['year'] as num?)?.toInt() ?? 0,
      reason: d['reason'] as String? ?? '',
      status: LeaveStatus.values.asNameMap()[d['status']] ?? LeaveStatus.pending,
      steps: [
        for (final s in d['steps'] as List<dynamic>? ?? const [])
          if (s is Map<String, dynamic>)
            ApprovalStep(
              role: UserRole.fromValue(s['role'] as String?),
              uid: s['uid'] as String?,
              status: LeaveStatus.values.asNameMap()[s['status']] ?? LeaveStatus.pending,
              byId: s['byId'] as String?,
              at: (s['at'] as Timestamp?)?.toDate(),
              comment: s['comment'] as String? ?? '',
            ),
      ],
      stepIndex: (d['stepIndex'] as num?)?.toInt() ?? 0,
      awaitingKey: d['awaitingKey'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      watcherIds: [for (final id in d['watcherIds'] as List<dynamic>? ?? const []) if (id is String) id],
    );
  }
}

Map<String, dynamic> _stepMap(ApprovalStep s) => {
      'role': s.role.value,
      'uid': s.uid,
      'status': s.status.name,
      'byId': s.byId,
      'at': s.at == null ? null : Timestamp.fromDate(s.at!),
      'comment': s.comment,
    };

final _db = FirebaseFirestore.instance;
final _requests = _db.collection('leave_requests');
final _typesDoc = _db.doc('settings/leaveTypes');
final _holidaysDoc = _db.doc('settings/holidays');

List<LeaveRequest> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) {
  final list = s.docs.map(LeaveRequest.fromDoc).toList();
  final now = DateTime.now();
  list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
  return list;
}

/// Leave types set by HR, or the Saudi-law defaults until HR saves a list.
final leaveTypesProvider = StreamProvider<List<LeaveType>>((ref) => _typesDoc.snapshots().map((s) {
      final list = s.data()?['types'] as List<dynamic>?;
      if (list == null) return LeaveType.defaults;
      return [for (final t in list) if (t is Map<String, dynamic>) LeaveType.fromMap(t)];
    }));

/// Public holidays ('yyyy-MM-dd') entered by HR; they don't count as leave days.
final holidaysProvider = StreamProvider<Set<String>>((ref) => _holidaysDoc
    .snapshots()
    .map((s) => {for (final d in s.data()?['dates'] as List<dynamic>? ?? const []) if (d is String) d}));

/// The signed-in user's own requests.
final myLeaveRequestsProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  return _requests.where('uid', isEqualTo: me.id).snapshots().map(_newestFirst);
});

/// One person's requests (HR area: balances of someone else).
final userLeaveRequestsProvider = StreamProvider.family<List<LeaveRequest>, String>(
    (ref, uid) => _requests.where('uid', isEqualTo: uid).snapshots().map(_newestFirst));

/// Every request, newest first (HR area only, by the rules).
final allLeaveRequestsProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  // Managers too: their people's leave on the Attendance page / report (2026-10-23).
  if (me == null || !me.seesTeamAttendance) return Stream.value(const []);
  // A KAM may read only their team's requests (rules).
  if (me.role == UserRole.kam) {
    return _requests.where('kamId', isEqualTo: me.id).snapshots().map(_newestFirst);
  }
  return _requests.orderBy('createdAt', descending: true).limit(500).snapshots().map(_newestFirst);
});

final leaveRequestProvider = StreamProvider.family<LeaveRequest?, String>(
    (ref, id) => _requests.doc(id).snapshots().map((s) => s.exists ? LeaveRequest.fromDoc(s) : null));

/// Requests whose current step is the signed-in user's. Outside the HR area
/// only the direct manager's step (by uid) can be theirs.
final leaveAwaitingMeProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  final keys = ['uid:${me.id}', 'role:${me.role.value}'];
  final Query<Map<String, dynamic>> query;
  if (me.role.canSeeHr) {
    query = _requests.where('awaitingKey', whereIn: keys);
  } else {
    query = _requests.where('awaitingKey', isEqualTo: 'uid:${me.id}');
  }
  return query.snapshots().map((s) => _newestFirst(s)
      .where((r) => canDecide(me: me, requesterId: r.uid, awaitingKey: r.awaitingKey))
      .toList());
});

/// HR's numbers for one person and year: `leave_balances/{uid}_{year}`.
class LeaveBalanceRecord {
  const LeaveBalanceRecord({required this.entitled, required this.adjustments, this.carried = const {}});

  static const empty = LeaveBalanceRecord(entitled: {}, adjustments: []);

  /// Moved from the previous leave year when it closed (`closeLeaveYears`
  /// Cloud Function): {annual: days}, negative = overdrawn.
  final Map<String, num> carried;

  /// Days per type id for this person (overrides the type's yearly days).
  final Map<String, num> entitled;
  final List<({String typeId, double days, String note, String byId, DateTime? at})> adjustments;

  List<LeaveAdjustment> get forBalance => [for (final a in adjustments) (typeId: a.typeId, days: a.days)];

  factory LeaveBalanceRecord.fromMap(Map<String, dynamic>? d) {
    if (d == null) return empty;
    return LeaveBalanceRecord(
      entitled: {
        for (final e in (d['entitled'] as Map<String, dynamic>? ?? const {}).entries)
          if (e.value is num) e.key: e.value as num,
      },
      carried: {
        for (final e in (d['carried'] as Map<String, dynamic>? ?? const {}).entries)
          if (e.value is num) e.key: e.value as num,
      },
      adjustments: [
        for (final a in d['adjustments'] as List<dynamic>? ?? const [])
          if (a is Map<String, dynamic>)
            (
              typeId: a['typeId'] as String? ?? '',
              days: (a['days'] as num?)?.toDouble() ?? 0,
              note: a['note'] as String? ?? '',
              byId: a['byId'] as String? ?? '',
              at: (a['at'] as Timestamp?)?.toDate(),
            ),
      ],
    );
  }
}

String balanceDocId(String uid, int year) => '${uid}_$year';

final leaveBalanceRecordProvider = StreamProvider.family<LeaveBalanceRecord, (String, int)>((ref, key) => _db
    .collection('leave_balances')
    .doc(balanceDocId(key.$1, key.$2))
    .snapshots()
    .map((s) => LeaveBalanceRecord.fromMap(s.data())));

final leaveRepositoryProvider = Provider((ref) => LeaveRepository());

class LeaveRepository {
  /// Saves a new request at the first step of [chain] and tells that step's
  /// approvers. Files (e.g. a hospital report) are uploaded after the request
  /// exists, since Storage rules check the request's owner. Returns its id.
  Future<String> submit({
    required AppUser me,
    required LeaveType type,
    required String? from,
    required String? to,
    required bool halfDay,
    String? travelDay,
    String? departureTime,
    required double days,
    required String reason,
    required List<ApprovalStep> chain,
    required List<PendingFile> files,
    required List<AppUser> users,
  }) => saving(() async {
    final doc = _requests.doc();
    final watchers = leaveWatchers(me, chain, users);
    await doc.set({
      'uid': me.id,
      'kamId': chain.where((s) => s.role == UserRole.kam).firstOrNull?.uid,
      // The direct manager's step (rules: they may read the request).
      'managerId': chain.where((s) => s.uid != null).firstOrNull?.uid,
      'watcherIds': watchers,
      'typeId': type.id,
      'typeEn': type.en,
      'typeAr': type.ar,
      'isLeave': type.isLeave,
      'paid': type.paid,
      'from': from,
      'to': to,
      'halfDay': halfDay,
      // Departure on the first day picked; after work, [from] is the next work day.
      'travelDay': ?travelDay,
      'departureTime': ?departureTime,
      'days': days,
      // The leave year (from their joining date) it uses days of.
      'year': leaveYearOf(me.joiningDate, from == null ? DateTime.now() : DateTime.parse(from)),
      'reason': reason,
      'status': LeaveStatus.pending.name,
      'steps': [for (final s in chain) _stepMap(s)],
      'stepIndex': 0,
      'awaitingKey': chain.first.awaitingKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final attachments = AttachmentsRepository();
    for (final f in files) {
      await attachments.upload((parent: AttachmentParent.leaveRequests, id: doc.id), f, me.id);
    }
    await _notifyStep(chain.first, fromId: me.id, ownerId: me.id, requestId: doc.id, users: users);
    await _notifyWatchers(watchers, LeaveUpdate.sent, fromId: me.id, ownerId: me.id, requestId: doc.id);
    return doc.id;
  });

  /// HR / GM accept a reported absence ([absenceId]) as leave of [type] for
  /// [person] on [date] (2026-10-22): an already approved one-day request,
  /// so it counts against their balance and shows as leave everywhere.
  /// Returns its id.
  Future<String> recordAbsenceLeave({
    required AppUser me,
    required AppUser person,
    required LeaveType type,
    required String date,
    required double days,
    required String reason,
    required String comment,
    required String absenceId,
  }) => saving(() async {
    final doc = _requests.doc();
    final step = ApprovalStep(role: me.role, uid: me.id)
        .decide(approve: true, byId: me.id, at: DateTime.now(), comment: comment);
    await doc.set({
      'uid': person.id,
      'kamId': person.role == UserRole.salesExec ? person.kamId : null,
      'typeId': type.id,
      'typeEn': type.en,
      'typeAr': type.ar,
      'isLeave': true,
      'paid': type.paid,
      'from': date,
      'to': date,
      'halfDay': false,
      'days': days,
      'year': leaveYearOf(person.joiningDate, DateTime.parse(date)),
      'reason': reason,
      'status': LeaveStatus.approved.name,
      'steps': [_stepMap(step)],
      'stepIndex': 0,
      'awaitingKey': null,
      'absenceId': absenceId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'decidedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  });

  /// The owner withdraws a request that is still waiting.
  Future<void> cancel(LeaveRequest r) => saving(() async {
        await _requests.doc(r.id).update({
          'status': LeaveStatus.cancelled.name,
          'awaitingKey': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _notifyWatchers(r.watcherIds, LeaveUpdate.cancelled, fromId: r.uid, ownerId: r.uid, requestId: r.id);
      });

  /// The current approver approves (the request moves to the next step, or is
  /// approved after the last) or rejects (it ends). In a transaction, so two
  /// managers with the same role can't both decide the same step.
  Future<void> decide({
    required String id,
    required AppUser me,
    required bool approve,
    required String comment,
    required List<AppUser> users,
  }) => saving(() async {
    final next = await _db.runTransaction<(LeaveRequest, ApprovalStep?)?>((tx) async {
      final snap = await tx.get(_requests.doc(id));
      final r = LeaveRequest.fromDoc(snap);
      if (!canDecide(me: me, requesterId: r.uid, awaitingKey: r.awaitingKey)) return null;
      final steps = [...r.steps];
      steps[r.stepIndex] = steps[r.stepIndex].decide(approve: approve, byId: me.id, at: DateTime.now(), comment: comment);
      final nextStep = approve && r.stepIndex + 1 < steps.length ? steps[r.stepIndex + 1] : null;
      tx.update(snap.reference, {
        'steps': [for (final s in steps) _stepMap(s)],
        'stepIndex': nextStep == null ? r.stepIndex : r.stepIndex + 1,
        'awaitingKey': nextStep?.awaitingKey,
        'status': nextStep != null
            ? LeaveStatus.pending.name
            : (approve ? LeaveStatus.approved : LeaveStatus.rejected).name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (nextStep == null) 'decidedAt': FieldValue.serverTimestamp(),
      });
      return (r, nextStep);
    });
    if (next == null) throw StateError('already decided');
    final (r, nextStep) = next;
    await _notifyWatchers(
      r.watcherIds,
      nextStep != null ? LeaveUpdate.stepApproved : (approve ? LeaveUpdate.approved : LeaveUpdate.rejected),
      fromId: me.id,
      ownerId: r.uid,
      requestId: id,
    );
    if (nextStep != null) {
      await _notifyStep(nextStep, fromId: me.id, ownerId: r.uid, requestId: id, users: users);
      // The person hears that their manager approved and HR is next.
      await sendNotifications(
        toIds: [r.uid],
        type: NotificationType.leaveStepApproved,
        fromId: me.id,
        ownerId: r.uid,
        date: '',
        count: 0,
        ref: id,
      );
    } else {
      await sendNotifications(
        toIds: [r.uid],
        type: approve ? NotificationType.leaveApproved : NotificationType.leaveRejected,
        fromId: me.id,
        ownerId: r.uid,
        date: '',
        count: 0,
        ref: id,
      );
      // Their direct manager should know who is on leave (2026-10-22);
      // not those who approved a step.
      final person = users.where((u) => u.id == r.uid).firstOrNull;
      if (approve && r.isLeave && r.from != null && person != null) {
        final approvers = {for (final s in r.steps) ?s.byId, me.id};
        await sendNotifications(
          toIds: [for (final m in directManagersOf(person, users)) if (!approvers.contains(m)) m],
          type: NotificationType.teamOnLeave,
          fromId: me.id,
          ownerId: r.uid,
          date: r.from!,
          count: 0,
          ref: id,
          note: r.to ?? r.from!,
        );
      }
    }
  });

  /// `leaveUpdate` to the people only informed ([LeaveRequest.watcherIds]).
  Future<void> _notifyWatchers(
    List<String> watcherIds,
    LeaveUpdate update, {
    required String fromId,
    required String ownerId,
    required String requestId,
  }) =>
      sendNotifications(
        toIds: watcherIds,
        type: NotificationType.leaveUpdate,
        fromId: fromId,
        ownerId: ownerId,
        date: '',
        count: 0,
        ref: requestId,
        issue: update.name,
      );

  Future<void> _notifyStep(
    ApprovalStep step, {
    required String fromId,
    required String ownerId,
    required String requestId,
    required List<AppUser> users,
  }) =>
      sendNotifications(
        toIds: step.uid != null
            ? [step.uid!]
            : [for (final u in users) if (u.active && u.role == step.role && u.id != ownerId) u.id],
        type: NotificationType.leaveRequested,
        fromId: fromId,
        ownerId: ownerId,
        date: '',
        count: 0,
        ref: requestId,
      );

  Future<void> saveTypes(List<LeaveType> types) => saving(() => _typesDoc.set({'types': [for (final t in types) t.toMap()]}));

  Future<void> saveHolidays(Set<String> dates) => saving(() => _holidaysDoc.set({'dates': (dates.toList()..sort())}));

  /// HR sets [uid]'s days for [typeId] in [year]; null = back to the type's number.
  Future<void> setEntitled(String uid, int year, String typeId, num? days) => saving(() =>
      _db.collection('leave_balances').doc(balanceDocId(uid, year)).set({
        'uid': uid,
        'year': year,
        'entitled': {typeId: days ?? FieldValue.delete()},
      }, SetOptions(merge: true)));

  /// HR adds (or with negative [days] removes) days, e.g. carried over from last year.
  Future<void> addAdjustment(String uid, int year, String typeId, double days, String note, String byId) => saving(() =>
      _db.collection('leave_balances').doc(balanceDocId(uid, year)).set({
        'uid': uid,
        'year': year,
        'adjustments': FieldValue.arrayUnion([
          {'typeId': typeId, 'days': days, 'note': note, 'byId': byId, 'at': Timestamp.now()},
        ]),
      }, SetOptions(merge: true)));
}
