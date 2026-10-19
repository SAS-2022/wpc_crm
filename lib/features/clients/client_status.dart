import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../notifications/notifications.dart';
import 'client.dart';
import 'transfer.dart';

// Client status (user request 2026-10-19): the salesperson marks a client as
// closed or not working; their KAM, the sales manager or the GM approves it
// (any one of them). KAM / managers change the status of clients they look
// after directly. Lists and the map show active clients unless the status
// filter says otherwise.

/// `clients.status`; missing = active.
enum ClientStatus {
  active('active'),
  closed('closed'),
  notWorking('notWorking');

  const ClientStatus(this.key);

  final String key;

  static ClientStatus fromKey(Object? key) => values.where((s) => s.key == key).firstOrNull ?? active;
}

/// A change waiting for approval (`clients.statusRequest`).
class StatusRequest {
  const StatusRequest({required this.status, required this.byId, required this.at, this.note = ''});

  final ClientStatus status;
  final String byId;
  final DateTime? at;
  final String note;

  static StatusRequest? fromMap(Object? m) => m is Map && m['byId'] is String
      ? StatusRequest(
          status: ClientStatus.fromKey(m['status']),
          byId: m['byId'] as String,
          at: (m['at'] as Timestamp?)?.toDate(),
          note: m['note'] as String? ?? '',
        )
      : null;
}

/// One entry of `clients.statusLog`: a change made, approved or rejected.
class StatusChange {
  const StatusChange({
    required this.status,
    required this.requestedBy,
    required this.decidedBy,
    required this.approved,
    required this.at,
    this.note = '',
    this.comment = '',
  });

  final ClientStatus status;

  /// '' when a KAM / manager changed it directly.
  final String requestedBy;
  final String decidedBy;
  final bool approved;
  final DateTime? at;
  final String note;
  final String comment;

  factory StatusChange.fromMap(Map<dynamic, dynamic> m) => StatusChange(
        status: ClientStatus.fromKey(m['status']),
        requestedBy: m['requestedBy'] as String? ?? '',
        decidedBy: m['decidedBy'] as String? ?? '',
        approved: m['approved'] as bool? ?? true,
        at: (m['at'] as Timestamp?)?.toDate(),
        note: m['note'] as String? ?? '',
        comment: m['comment'] as String? ?? '',
      );

  Map<String, Object> toMap() => {
        'status': status.key,
        'requestedBy': requestedBy,
        'decidedBy': decidedBy,
        'approved': approved,
        'at': Timestamp.fromDate(at ?? DateTime.now()),
        if (note.isNotEmpty) 'note': note,
        if (comment.isNotEmpty) 'comment': comment,
      };
}

/// Whether [me] looks after [client] as KAM / manager: the sales manager /
/// GM always; a KAM for their team's and unassigned clients, but not for
/// clients assigned to the KAM themselves (those go to the managers).
bool _overseesClient(AppUser me, Client client, Map<String, AppUser> users) {
  if (me.role.isAdmin) return true;
  return me.role == UserRole.kam && client.assignedTo != me.id && canTransferFrom(me, client.assignedTo, users);
}

/// KAM / managers change the status without approval.
bool canSetStatusDirectly(AppUser me, Client client, Map<String, AppUser> users) =>
    _overseesClient(me, client, users);

/// The salesperson the client is assigned to asks for a change.
bool canRequestStatus(AppUser me, Client client) => me.role.isSales && client.assignedTo == me.id;

/// Whether [me] may approve / reject the pending request (never their own).
bool canDecideStatus(AppUser me, Client client, Map<String, AppUser> users) {
  final req = client.statusRequest;
  return req != null && req.byId != me.id && _overseesClient(me, client, users);
}

/// Who is asked to approve [requester]'s request: their KAM (for a sales
/// exec) and every active sales manager and GM.
List<String> statusApprovers(AppUser requester, List<AppUser> users) => [
      for (final u in users)
        if (u.active &&
            u.id != requester.id &&
            (u.role.isAdmin || (u.role == UserRole.kam && requester.role == UserRole.salesExec && u.id == requester.kamId)))
          u.id,
    ];

DocumentReference<Map<String, dynamic>> _client(String id) => FirebaseFirestore.instance.collection('clients').doc(id);

/// The owner asks for [status]; the approvers are notified.
Future<void> requestClientStatus(
  Client client,
  ClientStatus status, {
  required AppUser me,
  required List<AppUser> users,
  String note = '',
}) =>
    saving(() async {
      await _client(client.id).update({
        'statusRequest': {
          'status': status.key,
          'byId': me.id,
          'at': FieldValue.serverTimestamp(),
          if (note.isNotEmpty) 'note': note,
        },
      });
      await sendNotifications(
        toIds: statusApprovers(me, users),
        type: NotificationType.clientStatusRequested,
        fromId: me.id,
        ownerId: me.id,
        date: '',
        count: 0,
        ref: client.id,
        issue: status.key,
        clientName: client.name,
      );
    });

/// The requester withdraws their request.
Future<void> cancelClientStatusRequest(Client client) =>
    saving(() => _client(client.id).update({'statusRequest': null}));

/// Approves or rejects the pending request and tells the requester.
Future<void> decideClientStatus(Client client, {required bool approve, required AppUser me, String comment = ''}) =>
    saving(() async {
      final req = client.statusRequest;
      if (req == null) return;
      final change = StatusChange(
        status: req.status,
        requestedBy: req.byId,
        decidedBy: me.id,
        approved: approve,
        at: DateTime.now(),
        note: req.note,
        comment: comment,
      );
      await _client(client.id).update({
        'statusRequest': null,
        if (approve) 'status': req.status.key,
        if (approve) 'statusAt': FieldValue.serverTimestamp(),
        'statusLog': FieldValue.arrayUnion([change.toMap()]),
      });
      await sendNotifications(
        toIds: [req.byId],
        type: approve ? NotificationType.clientStatusApproved : NotificationType.clientStatusRejected,
        fromId: me.id,
        ownerId: req.byId,
        date: '',
        count: 0,
        ref: client.id,
        issue: req.status.key,
        clientName: client.name,
      );
    });

/// KAM / managers: changes the status at once (also back to active). A
/// pending request is closed by it.
Future<void> setClientStatus(Client client, ClientStatus status, {required AppUser me, String note = ''}) =>
    saving(() => _client(client.id).update({
          'status': status.key,
          'statusAt': FieldValue.serverTimestamp(),
          'statusRequest': null,
          'statusLog': FieldValue.arrayUnion([
            StatusChange(status: status, requestedBy: '', decidedBy: me.id, approved: true, at: DateTime.now(), note: note)
                .toMap(),
          ]),
        }));
