import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/transfer.dart';
import '../clients/transfer_dialog.dart';
import '../notifications/notifications.dart';
import '../users/users_repository.dart';
import 'plan_repository.dart';
import 'plan_task.dart';

/// Selected clients split for "Add to plan": each goes on the plan of the
/// salesperson it belongs to.
typedef PlanSplit = ({
  /// Owner id → their clients (an active sales exec or KAM [me] may plan for).
  Map<String, List<Client>> byOwner,

  /// No owner, or the owner is no longer an active sales exec / KAM.
  List<Client> unassigned,

  /// Belongs to someone outside a KAM's team.
  List<Client> notAllowed,
});

/// Splits [clients] by owner for [me] (KAM / sales manager / GM). A KAM
/// plans only for their team and themselves, like transfers. [moved]:
/// client id → owner just set (the client objects may still be the old ones).
PlanSplit splitForPlans(
  List<Client> clients,
  AppUser me,
  Map<String, AppUser> users, {
  Map<String, String?> moved = const {},
}) {
  final byOwner = <String, List<Client>>{};
  final unassigned = <Client>[];
  final notAllowed = <Client>[];
  for (final c in clients) {
    final owner = users[moved.containsKey(c.id) ? moved[c.id] : c.assignedTo];
    if (owner == null || !owner.active || !owner.role.isTracked) {
      unassigned.add(c);
    } else if (!canTransferFrom(me, owner.id, users)) {
      notAllowed.add(c);
    } else {
      (byOwner[owner.id] ??= []).add(c);
    }
  }
  return (byOwner: byOwner, unassigned: unassigned, notAllowed: notAllowed);
}

/// Clients map selection → "Add to plan" (user decision 2026-10-18): puts
/// each client on its own salesperson's plan for a chosen day, approved,
/// and tells each of them. Clients without a salesperson are reported, with
/// the option to move them to someone first. Returns true when plans changed.
Future<bool> addSelectionToPlans(BuildContext context, WidgetRef ref, List<Client> selected) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final locale = Localizations.localeOf(context).toString();
  final me = ref.read(currentUserProvider).value;
  if (me == null || !me.role.isSupervisor || selected.isEmpty) return false;
  final users = {for (final u in ref.read(usersProvider).value ?? const <AppUser>[]) u.id: u};

  final clients = [...selected];
  final moved = <String, String?>{};
  var split = splitForPlans(clients, me, users);

  if (split.unassigned.isNotEmpty) {
    final names = split.unassigned.take(5).map((c) => c.name).join('، ');
    final more = split.unassigned.length > 5 ? ' +${split.unassigned.length - 5}' : '';
    final others = split.byOwner.values.fold(0, (n, l) => n + l.length);
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => PointerInterceptor(
        child: AlertDialog(
          icon: Icon(Icons.error_outline, color: Theme.of(dialog).colorScheme.error),
          title: Text(l10n.notAssignedTitle),
          content: Text(l10n.notAssignedBody(split.unassigned.length, '$names$more')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
            if (others > 0)
              TextButton(onPressed: () => Navigator.pop(dialog, 'skip'), child: Text(l10n.planTheOthers(others))),
            FilledButton(onPressed: () => Navigator.pop(dialog, 'move'), child: Text(l10n.moveThemFirst)),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return false;
    if (action == 'move') {
      await showTransferDialog(context, ref, split.unassigned, onMoved: (list, toId) {
        for (final c in list) {
          moved[c.id] = toId;
        }
      });
      if (!context.mounted) return false;
      split = splitForPlans(clients, me, users, moved: moved);
    }
  }
  if (split.byOwner.isEmpty) {
    if (split.notAllowed.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text(l10n.planNotAllowed(split.notAllowed.length))));
    return false;
  }

  // Day and summary.
  final today = DateTime.now();
  var day = DateTime(today.year, today.month, today.day);
  final owners = split.byOwner.keys.toList()..sort((a, b) => users[a]!.name.compareTo(users[b]!.name));
  final total = owners.fold(0, (n, o) => n + split.byOwner[o]!.length);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => PointerInterceptor(
        child: AlertDialog(
          title: Text(l10n.planSelectedTitle(total)),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat.yMMMEd(locale).format(day)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialog,
                      initialDate: day,
                      firstDate: DateTime(today.year, today.month, today.day),
                      lastDate: today.add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => day = picked);
                  },
                ),
                const SizedBox(height: 8),
                for (final o in owners)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(users[o]!.name),
                    trailing: Text('${split.byOwner[o]!.length}'),
                  ),
                if (split.notAllowed.isNotEmpty)
                  Text(
                    l10n.planNotAllowed(split.notAllowed.length),
                    style: TextStyle(color: Theme.of(dialog).colorScheme.error),
                  ),
                Text(l10n.planSelectedHint, style: Theme.of(dialog).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.addToPlan)),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return false;

  final date = dayKey(day);
  final repo = ref.read(planRepositoryProvider);
  var added = 0, already = 0, plans = 0;
  try {
    for (final o in owners) {
      // Clients already on that day's plan (not rejected) are left out.
      final existing = await ref.read(dayTasksProvider((o, date)).future);
      final planned = {
        for (final t in existing)
          if (t.clientId != null && t.approval != TaskApproval.rejected) t.clientId!,
      };
      final fresh = split.byOwner[o]!.where((c) => !planned.contains(c.id)).toList();
      already += split.byOwner[o]!.length - fresh.length;
      if (fresh.isEmpty) continue;
      await repo.addMany(
        ownerId: o,
        date: date,
        createdBy: me.id,
        approved: true,
        clients: [for (final c in fresh) (id: c.id, name: c.name)],
      );
      if (o != me.id) {
        await sendNotifications(
          toIds: [o],
          type: NotificationType.planItemsAdded,
          fromId: me.id,
          ownerId: o,
          date: date,
          count: fresh.length,
        );
      }
      added += fresh.length;
      plans++;
    }
    messenger.showSnackBar(SnackBar(
      content: Text([
        l10n.plannedFromSelection(added, plans),
        if (already > 0) l10n.alreadyOnPlanCount(already),
      ].join(' · ')),
    ));
    return added > 0;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    return added > 0;
  }
}
