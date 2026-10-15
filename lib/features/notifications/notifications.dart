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
  /// 'notAlways', 'battery' or 'offline' (offline 30 min, `offlineAlerts`).
  final String issue;
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
