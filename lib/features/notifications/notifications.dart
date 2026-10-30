import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';

/// What happened, rendered in the reader's language.
enum NotificationType {
  /// A sales exec saved items to their plan, waiting for approval.
  planSubmitted,

  /// A KAM / manager approved the pending items.
  planApproved,

  /// A KAM / manager rejected an item.
  planRejected,

  /// A KAM / manager added or removed items in someone's plan.
  planChanged,

  /// A KAM / manager added [AppNotification.count] items to someone's plan
  /// (already approved).
  planItemsAdded,

  /// A KAM / manager moved clients to the recipient (count = how many).
  clientsTransferredIn,

  /// A KAM / manager moved the recipient's clients to `ownerId` (empty =
  /// unassigned); their open plan items for those clients were removed.
  clientsTransferredOut,

  /// Written by the `trackingAlerts` Cloud Function: the sales exec
  /// (`fromId`) turned off GPS, reduced the location permission or turned on
  /// battery optimization during work hours. See [AppNotification.issue].
  trackingIssue,

  /// A leave request by `ownerId` reached the recipient's approval step
  /// ([AppNotification.ref] = request id).
  leaveRequested,

  /// The recipient's leave request was approved by every step / rejected.
  leaveApproved,
  leaveRejected,

  /// The recipient's leave request passed a step (their direct manager) and
  /// now waits for the next one (HR).
  leaveStepApproved,

  /// Written by the `leaveReminders` Cloud Function every 24 h while
  /// `ownerId`'s request waits at the recipient's step ([AppNotification.count] = days).
  leaveReminder,

  /// For the people only informed of `ownerId`'s request (GM; SM for sales
  /// executives): [AppNotification.issue] = a [LeaveUpdate] name.
  leaveUpdate,

  /// `ownerId` asked to mark client [AppNotification.ref] as
  /// [AppNotification.issue] ('closed' / 'notWorking' / 'active').
  clientStatusRequested,

  /// The recipient's status request was approved / rejected.
  clientStatusApproved,
  clientStatusRejected,

  /// An admin asks the recipient to install the latest app version.
  updateReminder,

  /// `ownerId` registered an account (written by the `registrationRequested`
  /// Cloud Function for the sales managers / GMs).
  registrationRequested,

  /// `ownerId` checked in (first time that day, `attendanceUpdated` Cloud
  /// Function); sent to them and every active GM. [AppNotification.count] =
  /// minutes late, [AppNotification.time] = check-in time.
  attendanceCheckedIn,

  /// Not checked in 15 minutes after the start of their work day
  /// (`attendanceReminders`); [AppNotification.time] = start time.
  attendanceLate,

  /// At their work site (live GPS, `atSiteReminders`, 2026-10-28) but not
  /// checked in; [AppNotification.time] = arrival, count 1 = the reminder.
  attendanceAtSite,

  /// `ownerId` reported "not coming to work" on [AppNotification.date]
  /// (`absenceReported` Cloud Function, to their KAM, HR and the GMs);
  /// [AppNotification.issue] = reason (sick / tired / cantCome),
  /// [AppNotification.note] = what they wrote; [AppNotification.ref] = absence id.
  absenceReported,

  /// HR / the GM accepted the recipient's absence as leave
  /// ([AppNotification.issue] = 'sick' / 'annual') or rejected it.
  absenceAccepted,
  absenceRejected,

  /// `ownerId`, someone the recipient manages directly, is on leave from
  /// [AppNotification.date] to [AppNotification.note] ('yyyy-MM-dd');
  /// [AppNotification.ref] = leave request id.
  teamOnLeave,

  /// `ownerId` asks the recipient (a direct manager) to check out before
  /// the end of today's work day; [AppNotification.note] = reason,
  /// [AppNotification.ref] = `checkout_requests` id (early_checkout.dart).
  earlyCheckoutRequested,

  /// The recipient's early check-out was approved / rejected
  /// ([AppNotification.note] = the manager's comment).
  earlyCheckoutApproved,
  earlyCheckoutRejected,

  /// `ownerId`'s overtime started (2026-10-25): [AppNotification.issue]
  /// 'site' = they pressed "Start overtime" (to their direct managers, who
  /// approve it later); 'driving' = a driver still on the road after the
  /// end (to the driver too, with the overtime sound). Before 2026-10-25:
  /// still at the site at the end. [AppNotification.time] = end of the
  /// shift, [AppNotification.siteName].
  overtimeStarted,

  /// "Start overtime?" to the person still at the site 10 min after their
  /// end (2026-10-25; [AppNotification.count] 1 = the reminder; own sound).
  overtimeAsk,

  /// A vehicle's registration / insurance / inspection ([AppNotification.issue],
  /// a `Renewal` name) expires on [AppNotification.date] in
  /// [AppNotification.count] days (≤ 0: expired); `vehicleRenewals` Cloud
  /// Function, to logistics managers, sales managers and GMs.
  /// [AppNotification.ref] = vehicle id, [AppNotification.vehicleName] = plate.
  vehicleRenewalDue,

  /// A vehicle's oil change (2026-10-26): [AppNotification.count] km left
  /// (≤ 0: due), [AppNotification.note] = the odometer km it's due at; same
  /// people and fields as [vehicleRenewalDue].
  vehicleOilDue,
}

/// In-app notification in Firestore `notifications`. The `sendPush` Cloud
/// Function turns each new document into a phone push.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.fromId,
    required this.ownerId,
    required this.date,
    required this.count,
    this.issue = '',
    this.ref = '',
    this.clientName = '',
    this.siteName = '',
    this.time = '',
    this.note = '',
    this.vehicleName = '',
    required this.read,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String fromId;

  /// Whose plan it is about, and which day. For client transfers: the
  /// other sales executive, and no day.
  final String ownerId;
  final String date;
  final int count;

  /// For [NotificationType.trackingIssue]: 'gpsOff', 'locationDenied',
  /// 'notAlways', 'battery', 'notificationsOff' or 'offline' (offline 30 min, `offlineAlerts`).
  final String issue;

  /// The document it is about, e.g. a leave request id.
  final String ref;

  /// Client notifications: the client's name when it was sent.
  final String clientName;

  /// Attendance: the work site and 'HH:mm' (Saudi time).
  final String siteName;
  final String time;

  /// Free text sent with it (absence reason).
  final String note;

  /// Vehicle notifications: the plate when it was sent.
  final String vehicleName;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      type: NotificationType.values.asNameMap()[d['type']] ?? NotificationType.planChanged,
      fromId: d['fromId'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      date: d['date'] as String? ?? '',
      count: (d['count'] as num?)?.toInt() ?? 0,
      issue: d['issue'] as String? ?? '',
      ref: d['ref'] as String? ?? '',
      clientName: d['clientName'] as String? ?? '',
      siteName: d['siteName'] as String? ?? '',
      time: d['time'] as String? ?? '',
      note: d['note'] as String? ?? '',
      vehicleName: d['vehicleName'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

CollectionReference<Map<String, dynamic>> get _notifications =>
    FirebaseFirestore.instance.collection('notifications');

/// The signed-in user's latest notifications, newest first.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const []);
  return _notifications.where('toId', isEqualTo: me.id).limit(100).snapshots().map((s) {
    final list = s.docs.map(AppNotification.fromDoc).toList();
    final pending = DateTime.now();
    list.sort((a, b) => (b.createdAt ?? pending).compareTo(a.createdAt ?? pending));
    return list;
  });
});

final unreadCountProvider = Provider<int>(
  (ref) => (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length,
);

/// [person]'s direct manager(s) (user decision 2026-10-22, who should know
/// who is on leave; also who approves leaving early, 2026-10-23, and the
/// first leave approval, 2026-10-30): the one chosen on the user form
/// (`managerId`, when active); else a sales exec's KAM, else the sales
/// managers; a KAM's sales managers; drivers, warehouse supervisors and
/// workers the logistics manager; engineers, operators and workers of the
/// Production department the factory manager; everyone else's GMs (also
/// when no one fits). Same as `directManagers` in functions/index.js.
List<String> directManagersOf(AppUser person, List<AppUser> users) {
  final chosen = [for (final u in users) if (u.id == person.managerId && u.active && u.id != person.id) u.id];
  if (chosen.isNotEmpty) return chosen;
  List<String> withRole(UserRole r) => [for (final u in users) if (u.active && u.role == r && u.id != person.id) u.id];
  final found = switch (person.role) {
    UserRole.salesExec => [
        for (final u in users) if (u.id == person.kamId && u.active && u.role == UserRole.kam) u.id,
      ].ifEmpty(() => withRole(UserRole.salesManager)),
    UserRole.kam => withRole(UserRole.salesManager),
    // Drivers and warehouse supervisors: the logistics manager (2026-10-23).
    UserRole.engineer || UserRole.operator => withRole(UserRole.factoryManager),
    UserRole.worker when person.department == 'production' => withRole(UserRole.factoryManager),
    UserRole.driver || UserRole.warehouseSupervisor || UserRole.worker => withRole(UserRole.logisticsManager),
    UserRole.gm => const <String>[],
    _ => withRole(UserRole.gm),
  };
  return person.role == UserRole.gm ? found : found.ifEmpty(() => withRole(UserRole.gm));
}

/// The people under [me] (2026-10-23): those whose direct manager is
/// [me] ([directManagersOf]), plus a warehouse supervisor's drivers. HR /
/// SM / GM see everyone in the HR area, this is for the other managers.
List<AppUser> peopleUnder(AppUser me, List<AppUser> users) => [
      for (final u in users)
        if (u.id != me.id && (u.supervisorId == me.id || directManagersOf(u, users).contains(me.id))) u,
    ];

/// The drivers [me] follows: every one for the logistics manager / SM /
/// GM, their own for a warehouse supervisor.
List<AppUser> driversOf(AppUser me, List<AppUser> users) => [
      for (final u in users)
        if (u.active && u.role.isDriver && (me.role.managesDrivers || (me.role.seesDrivers && u.supervisorId == me.id))) u,
    ];

extension on List<String> {
  List<String> ifEmpty(List<String> Function() other) => isEmpty ? other() : this;
}

/// What happened to a request, for [NotificationType.leaveUpdate].
enum LeaveUpdate { sent, stepApproved, approved, rejected, cancelled }

/// Who reviews [owner]'s plan: their KAM, or the sales manager / GM when they
/// have no active KAM.
List<String> reviewersOf(AppUser owner, List<AppUser> users) {
  final kam = users.where((u) => u.id == owner.kamId && u.active).firstOrNull;
  if (kam != null) return [kam.id];
  return [for (final u in users) if (u.active && u.role.isAdmin) u.id];
}

Future<void> sendNotifications({
  required List<String> toIds,
  required NotificationType type,
  required String fromId,
  required String ownerId,
  required String date,
  required int count,
  String? ref,
  String? issue,
  String? clientName,
  String? note,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  for (final to in toIds.toSet()) {
    if (to == fromId) continue;
    batch.set(_notifications.doc(), {
      'toId': to,
      'type': type.name,
      'fromId': fromId,
      'ownerId': ownerId,
      'date': date,
      'count': count,
      'ref': ?ref,
      'issue': ?issue,
      'clientName': ?clientName,
      'note': ?note,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

Future<void> markRead(String id) => _notifications.doc(id).update({'read': true});

Future<void> markAllRead(List<AppNotification> list) async {
  final batch = FirebaseFirestore.instance.batch();
  for (final n in list.where((n) => !n.read)) {
    batch.update(_notifications.doc(n.id), {'read': true});
  }
  await batch.commit();
}
