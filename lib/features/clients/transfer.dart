import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_user.dart';
import '../plan/plan_task.dart';

/// One entry of a client's transfer log (`clients/{id}.transfers`).
class ClientTransfer {
  const ClientTransfer({required this.fromId, required this.toId, required this.byId, required this.at});

  /// Previous and new sales executive; null = unassigned.
  final String? fromId;
  final String? toId;
  final String byId;
  final DateTime? at;

  factory ClientTransfer.fromMap(Map<dynamic, dynamic> m) => ClientTransfer(
        fromId: m['fromId'] as String?,
        toId: m['toId'] as String?,
        byId: m['byId'] as String? ?? '',
        at: (m['at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'fromId': fromId,
        'toId': toId,
        'byId': byId,
        'at': at == null ? null : Timestamp.fromDate(at!),
      };
}

/// Active sales executives [me] may move clients to: anyone for the sales
/// manager / GM, only their own team for a KAM.
List<AppUser> transferTargets(AppUser me, List<AppUser> users) => [
      for (final u in users)
        if (u.active && u.role == UserRole.salesExec && (me.role.isAdmin || (me.role == UserRole.kam && u.kamId == me.id)))
          u,
    ];

/// Whether [me] may move a client away from [ownerId] (null = unassigned):
/// the sales manager / GM always, a KAM only from themselves (clients Odoo
/// lists under the KAM) or a member of their team.
bool canTransferFrom(AppUser me, String? ownerId, Map<String, AppUser> users) {
  if (me.role.isAdmin) return true;
  if (me.role != UserRole.kam || ownerId == null) return false;
  return ownerId == me.id || users[ownerId]?.kamId == me.id;
}

/// Whether [me] may move clients to the unassigned pool.
bool canUnassign(AppUser me) => me.role.isAdmin;

/// The plan items a transfer removes: items of the previous owner
/// ([previousOwner] by client id) for the moved clients, dated [today] or
/// later and not done. Past plans and visits stay as they were.
List<PlanTask> planItemsToDrop(List<PlanTask> tasks, Map<String, String?> previousOwner, String today) => [
      for (final t in tasks)
        if (t.clientId != null &&
            previousOwner.containsKey(t.clientId) &&
            t.ownerId == previousOwner[t.clientId] &&
            !t.done &&
            t.date.compareTo(today) >= 0)
          t,
    ];
