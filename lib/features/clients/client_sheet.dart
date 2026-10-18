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
              if (ref.read(currentUserProvider).value?.role.isTracked ?? false) ...[
                const SizedBox(height: 12),
                AddToTodayButton(client: c),
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

/// One tap puts the client on the user's plan for today; shows "On today's
/// plan" once it's there (any approval state, not done).
class AddToTodayButton extends ConsumerStatefulWidget {
  const AddToTodayButton({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<AddToTodayButton> createState() => AddToTodayButtonState();
}

class AddToTodayButtonState extends ConsumerState<AddToTodayButton> {
  bool _busy = false;

  Future<void> _add(AppUser me) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final approved = await addClientToTodayPlan(ref, me, widget.client);
      messenger.showSnackBar(SnackBar(content: Text(approved ? l10n.planUpdated(1) : l10n.planSentForApproval(1))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final tasks = ref.watch(dayTasksProvider((me.id, dayKey(DateTime.now())))).value;
    final onPlan =
        tasks?.any((t) => t.clientId == widget.client.id && !t.done && t.approval != TaskApproval.rejected) ?? false;
    return FilledButton.tonalIcon(
      onPressed: onPlan || _busy || tasks == null ? null : () => _add(me),
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(onPlan ? Icons.event_available : Icons.playlist_add),
      label: Text(onPlan ? l10n.onTodaysPlan : l10n.addToTodaysPlan),
    );
  }
}
