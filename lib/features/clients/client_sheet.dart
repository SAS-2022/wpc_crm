import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../plan/add_task_sheet.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import 'client.dart';
import 'person_style.dart';
import 'transfer.dart';
import 'transfer_dialog.dart';

/// The client sheet shown when a client pin is tapped (clients map, route
/// history): owner, details, add visit / log call, today's plan and, on the
/// web, moving the client.
///
/// [place]: which of the client's locations was tapped, when it has several; [visit]: adds a button to open it;
/// [onSelectSeveral]: clients map, starts picking several clients to move.
void showClientSheet(
  BuildContext context,
  WidgetRef ref,
  Client c, [
  String? place,
  Visit? visit,
  VoidCallback? onSelectSeveral,
  // The pin tapped, for a client with several locations: planned there.
  ClientLocation? location,
]) {
  final l10n = AppLocalizations.of(context);
  final me = ref.read(currentUserProvider).value;
  final usersById = {for (final u in ref.read(usersProvider).value ?? const <AppUser>[]) u.id: u};
  final canMove = me != null && canTransferFrom(me, c.assignedTo, usersById);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => PointerInterceptor(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.name, style: Theme.of(context).textTheme.titleMedium),
              if (place != null || c.city.isNotEmpty) Text([?place, if (c.city.isNotEmpty) c.city].join(' · ')),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final name =
                      ref.read(usersProvider).value?.where((u) => u.id == c.assignedTo).firstOrNull?.name ??
                      l10n.unassigned;
                  return Row(
                    children: [
                      PersonBadge(userId: c.assignedTo, name: name, size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/clients/${c.id}');
                      },
                      child: Text(l10n.details),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/clients/${c.id}/visit');
                      },
                      icon: const Icon(Icons.add_location_alt),
                      label: Text(l10n.addVisit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/clients/${c.id}/call');
                },
                icon: const Icon(Icons.add_call),
                label: Text(l10n.logCall),
              ),
              // Route history: the visit behind the tapped pin.
              if (visit != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.push('/visits/${visit.id}');
                  },
                  icon: const Icon(Icons.event_note),
                  label: Text(l10n.visitDetails),
                ),
              ],
              if (ref.read(currentUserProvider).value?.role case final r? when r.isTracked || r.isSupervisor) ...[
                const SizedBox(height: 12),
                AddToTodayButton(client: c, locationId: location?.id),
              ],
              // Web dashboard: KAM / managers move the client to another salesperson.
              if (kIsWeb && canMove) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    showTransferDialog(context, ref, [c]);
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.moveToSalesperson),
                ),
              ],
              if (onSelectSeveral != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    onSelectSeveral();
                  },
                  icon: const Icon(Icons.checklist),
                  label: Text(l10n.selectSeveralToMove),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// One tap puts the client on today's plan; shows "On today's plan" once
/// it's there (any approval state, not done). Whose plan: a sales exec's own;
/// for a KAM / manager the client's salesperson when they may plan for them
/// (2026-10-21), and a KAM can pick their own plan instead (they may visit
/// alone) — asked when both are possible.
class AddToTodayButton extends ConsumerStatefulWidget {
  const AddToTodayButton({super.key, required this.client, this.locationId});

  final Client client;

  /// The client location to plan the visit at; null = the main one.
  final String? locationId;

  @override
  ConsumerState<AddToTodayButton> createState() => AddToTodayButtonState();
}

class AddToTodayButtonState extends ConsumerState<AddToTodayButton> {
  bool _busy = false;

  Future<void> _add(AppUser me, AppUser owner) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final approved =
          await addClientToTodayPlan(ref, me, widget.client, owner: owner, locationId: widget.locationId);
      messenger.showSnackBar(SnackBar(
        content: Text(owner.id != me.id
            ? l10n.addedToPersonsPlan(owner.name)
            : approved
            ? l10n.planUpdated(1)
            : l10n.planSentForApproval(1)),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// KAM: the salesperson's plan or their own.
  Future<void> _choose(AppUser me, List<AppUser> open) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<AppUser>(
      context: context,
      builder: (dialog) => PointerInterceptor(
        child: SimpleDialog(
          title: Text(l10n.addToWhosePlan),
          children: [
            for (final u in open)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialog, u),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(u.id == me.id ? Icons.person : Icons.person_outline),
                  title: Text(u.id == me.id ? l10n.myPlan : l10n.personsPlan(u.name)),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) await _add(me, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final owner = users[widget.client.assignedTo];
    final targets = [
      // The client's salesperson, when a KAM / manager may plan for them.
      if (me.role.isSupervisor &&
          owner != null &&
          owner.id != me.id &&
          owner.active &&
          owner.role.isTracked &&
          canTransferFrom(me, owner.id, users))
        owner,
      if (me.role.isTracked) me,
    ];
    if (targets.isEmpty) return const SizedBox.shrink();
    final today = dayKey(DateTime.now());
    final taskLists = [for (final t in targets) ref.watch(dayTasksProvider((t.id, today))).value];
    bool onPlan(int i) =>
        taskLists[i]?.any((t) => t.clientId == widget.client.id && !t.done && t.approval != TaskApproval.rejected) ??
        false;
    final open = [for (final (i, t) in targets.indexed) if (!onPlan(i)) t];
    final loading = taskLists.any((l) => l == null);
    final label = open.isEmpty
        ? (targets.first.id == me.id ? l10n.onTodaysPlan : l10n.onPersonsPlanToday(targets.first.name))
        : open.length == 1 && open.single.id != me.id
        ? l10n.addToPersonsPlanToday(open.single.name)
        : l10n.addToTodaysPlan;
    return FilledButton.tonalIcon(
      onPressed: open.isEmpty || _busy || loading
          ? null
          : () => open.length == 1 ? _add(me, open.single) : _choose(me, open),
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(open.isEmpty ? Icons.event_available : Icons.playlist_add),
      label: Text(label),
    );
  }
}
