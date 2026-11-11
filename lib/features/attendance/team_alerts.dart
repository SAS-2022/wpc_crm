import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';

// Team follow-ups (user request 2026-11-11): when an employee is late, asks
// for a break, asks to leave early or reports they won't come, the people
// they report to must act; nobody acting within App setting
// `alertEscalateMin` (30) → the people above them are told, and so on.
// Written by the Cloud Functions (functions/teamAlerts.js, same fields);
// the people told record what they did on the action page
// (`/team-alerts/:id`) — an action, or "no action taken". Deciding the
// request itself (approve / reject a break, leaving early, an absence)
// closes it automatically.

enum TeamAlertKind {
  late,
  breakRequest,
  earlyCheckout,
  absence;

  /// Stored value ('break' is a Dart keyword).
  String get key => this == breakRequest ? 'break' : name;

  static TeamAlertKind fromKey(Object? v) => switch (v) {
        'break' => breakRequest,
        'earlyCheckout' => earlyCheckout,
        'absence' => absence,
        _ => late,
      };
}

/// Ready-made answers on the action page (the text is in the UI language).
enum AlertActionPreset {
  called,
  toldInAdvance,
  reminded,
  talked,
  askedDocument,
  toHr,
  approved,
  rejected,
  other;

  static AlertActionPreset? fromKey(Object? v) => values.asNameMap()['$v'];
}

/// The answers offered for [kind] (always ending with [AlertActionPreset.other]).
List<AlertActionPreset> presetsFor(TeamAlertKind kind) => switch (kind) {
      TeamAlertKind.late => const [
          AlertActionPreset.called,
          AlertActionPreset.toldInAdvance,
          AlertActionPreset.reminded,
          AlertActionPreset.toHr,
          AlertActionPreset.other,
        ],
      TeamAlertKind.breakRequest || TeamAlertKind.earlyCheckout => const [
          AlertActionPreset.approved,
          AlertActionPreset.rejected,
          AlertActionPreset.talked,
          AlertActionPreset.other,
        ],
      TeamAlertKind.absence => const [
          AlertActionPreset.called,
          AlertActionPreset.askedDocument,
          AlertActionPreset.toHr,
          AlertActionPreset.other,
        ],
    };

class AlertStep {
  const AlertStep({required this.level, required this.toIds, this.at});

  final int level;
  final List<String> toIds;
  final DateTime? at;
}

class AlertAction {
  const AlertAction({required this.taken, this.note = '', this.byId, this.at, this.preset, this.auto});

  final bool taken;
  final String note;
  final String? byId;
  final DateTime? at;
  final AlertActionPreset? preset;

  /// Set by the server when the request was decided / taken back:
  /// 'approved' | 'rejected' | 'cancelled' | 'accepted'.
  final String? auto;
}

class TeamAlert {
  const TeamAlert({
    required this.id,
    required this.uid,
    required this.kind,
    required this.date,
    this.ref = '',
    this.note = '',
    this.count = 0,
    this.time = '',
    this.level = 0,
    this.toIds = const [],
    this.allIds = const [],
    this.steps = const [],
    this.open = true,
    this.action,
    this.nextAt,
    this.createdAt,
    this.topReached = false,
    this.dayOver = false,
  });

  final String id;

  /// The employee it is about.
  final String uid;
  final TeamAlertKind kind;

  /// 'yyyy-MM-dd'.
  final String date;

  /// The request (break / checkout / absence id; late: '{uid}_{date}').
  final String ref;
  final String note;

  /// Break minutes.
  final int count;

  /// Late: the work day's start 'HH:mm'.
  final String time;
  final int level;
  final List<String> toIds;
  final List<String> allIds;
  final List<AlertStep> steps;
  final bool open;
  final AlertAction? action;

  /// When it goes one level up (null = it won't any more).
  final DateTime? nextAt;
  final DateTime? createdAt;
  final bool topReached;
  final bool dayOver;

  bool get escalated => level > 0;

  /// [me] may record the action: told at any level, not the employee.
  bool canAct(String me) => open && me != uid && allIds.contains(me);

  /// Told [me] at the current level (it waits for them now).
  bool waitsFor(String me) => open && toIds.contains(me);

  factory TeamAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    List<String> ids(Object? v) => [if (v is List) for (final x in v) if (x is String) x];
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    final a = d['action'];
    return TeamAlert(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      kind: TeamAlertKind.fromKey(d['kind']),
      date: d['date'] as String? ?? '',
      ref: d['ref'] as String? ?? '',
      note: d['note'] as String? ?? '',
      count: (d['count'] as num?)?.toInt() ?? 0,
      time: d['time'] as String? ?? '',
      level: (d['level'] as num?)?.toInt() ?? 0,
      toIds: ids(d['toIds']),
      allIds: ids(d['allIds']),
      steps: [
        if (d['steps'] case final List l)
          for (final s in l)
            if (s is Map) AlertStep(level: (s['level'] as num?)?.toInt() ?? 0, toIds: ids(s['toIds']), at: time(s['at'])),
      ],
      open: d['status'] != 'done',
      action: a is Map
          ? AlertAction(
              taken: a['taken'] == true,
              note: a['note'] as String? ?? '',
              byId: a['byId'] as String?,
              at: time(a['at']),
              preset: AlertActionPreset.fromKey(a['preset']),
              auto: a['auto'] as String?,
            )
          : null,
      nextAt: time(d['nextAt']),
      createdAt: time(d['createdAt']),
      topReached: d['topReached'] == true,
      dayOver: d['dayOver'] == true,
    );
  }
}

CollectionReference<Map<String, dynamic>> get _alerts => FirebaseFirestore.instance.collection('team_alerts');

/// Every follow-up the signed-in person was told about, newest first.
final myTeamAlertsProvider = StreamProvider<List<TeamAlert>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  return _alerts.where('allIds', arrayContains: me.id).limit(300).snapshots().map((s) {
    final list = s.docs.map(TeamAlert.fromDoc).toList();
    final now = DateTime.now();
    list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return list;
  });
});

/// Open follow-ups the signed-in person may act on (Home card, badge).
final openTeamAlertsProvider = Provider<List<TeamAlert>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  return [for (final a in ref.watch(myTeamAlertsProvider).value ?? const <TeamAlert>[]) if (a.canAct(me.id)) a];
});

/// One employee's follow-ups of one day ('yyyy-MM-dd'), for their
/// attendance day (2026-11-11, user: the action taken is recorded on the
/// employee's attendance). HR / GM / SM read every one; other managers the
/// ones they were told about.
final dayTeamAlertsProvider = StreamProvider.family<List<TeamAlert>, ({String uid, String date})>((ref, key) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  if (me.can.canManageHr) {
    return _alerts
        .where('uid', isEqualTo: key.uid)
        .where('date', isEqualTo: key.date)
        .snapshots()
        .map((s) => s.docs.map(TeamAlert.fromDoc).toList());
  }
  // Same query as [myTeamAlertsProvider] (the SDK shares the listener).
  return _alerts.where('allIds', arrayContains: me.id).limit(300).snapshots().map((s) => [
        for (final d in s.docs)
          if (d.data()['uid'] == key.uid && d.data()['date'] == key.date) TeamAlert.fromDoc(d),
      ]);
});

final teamAlertProvider = StreamProvider.family<TeamAlert?, String>(
  (ref, id) => _alerts.doc(id).snapshots().map((d) => d.exists ? TeamAlert.fromDoc(d) : null),
);

/// Records what [me] did about [alert] (or that nothing was done) and
/// stops its escalation.
Future<void> recordAlertAction(
  TeamAlert alert,
  AppUser me, {
  required bool taken,
  AlertActionPreset? preset,
  String note = '',
}) =>
    saving(() => _alerts.doc(alert.id).update({
          'status': 'done',
          'nextAt': FieldValue.delete(),
          'action': {
            'taken': taken,
            'note': note.trim(),
            'byId': me.id,
            'at': FieldValue.serverTimestamp(),
            if (taken && preset != null) 'preset': preset.name,
          },
        }));
