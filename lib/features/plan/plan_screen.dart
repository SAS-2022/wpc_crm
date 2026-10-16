import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/client_location_dialog.dart';
import '../clients/clients_repository.dart';
import '../notifications/notifications.dart';
import '../users/users_repository.dart';
import 'add_task_sheet.dart';
import 'checklist.dart';
import 'plan_repository.dart';
import 'plan_task.dart';

/// A person's plan for one day. The owner adds tasks (waiting for approval if
/// they are a sales exec) and ticks free tasks; KAM / managers add, approve,
/// reject and remove. The plan can be shared as text or shown on a map.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, required this.userId, this.initialDate});

  final String userId;

  /// 'yyyy-MM-dd'; today when null.
  final String? initialDate;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late DateTime _day = DateTime.tryParse(widget.initialDate ?? '') ?? DateTime.now();

  Future<void> _notifyOwner(AppUser me, AppUser owner, NotificationType type, int count) => sendNotifications(
        toIds: [owner.id],
        type: type,
        fromId: me.id,
        ownerId: owner.id,
        date: dayKey(_day),
        count: count,
      );

  /// Sales exec: removes items not yet approved. KAM / manager: removes everything.
  Future<void> _clear(AppUser me, AppUser owner, List<PlanTask> tasks, bool everything) async {
    final l10n = AppLocalizations.of(context);
    final toDelete = everything ? tasks : tasks.where((t) => t.approval != TaskApproval.approved).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.clearPlanTitle),
        content: Text(everything ? l10n.clearPlanAll(toDelete.length) : l10n.clearPlanUnapproved(toDelete.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(planRepositoryProvider).deleteAll(toDelete);
    if (me.id != owner.id) await _notifyOwner(me, owner, NotificationType.planChanged, toDelete.length);
  }

  /// KAM / manager: change an item's note (or a free task's text).
  Future<void> _editTitle(AppUser me, AppUser owner, PlanTask t) async {
    final l10n = AppLocalizations.of(context);
    final text = await showTextInputDialog(
      context,
      title: t.isVisit ? t.clientName ?? '' : l10n.task,
      initialText: t.title,
      label: t.isVisit ? l10n.noteOptional : l10n.taskDescription,
    );
    if (text == null || text == t.title || (!t.isVisit && text.isEmpty)) return;
    await ref.read(planRepositoryProvider).setTitle(t.id, text);
    if (me.id != owner.id) await _notifyOwner(me, owner, NotificationType.planChanged, 1);
  }

  Future<void> _share(AppUser owner, List<PlanTask> tasks) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final clients = {for (final c in ref.read(allClientsProvider).value ?? const <Client>[]) c.id: c};
    final open = tasks.where((t) => t.approval != TaskApproval.rejected).toList();
    final visits = open.where((t) => t.isVisit).toList();
    final located = [for (final t in visits) if (clients[t.clientId]?.hasLocation ?? false) clients[t.clientId]!];
    String maps(Client c) => 'https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}';
    final lines = <String>[
      l10n.shareTitle(owner.name, DateFormat.yMMMEd(locale).format(_day)),
      '',
      for (final (i, t) in visits.indexed) ...[
        '${i + 1}. ${t.clientName}${clients[t.clientId]?.city.isNotEmpty ?? false ? ' – ${clients[t.clientId]!.city}' : ''}${t.done ? ' ✓' : ''}',
        if (t.title.isNotEmpty) '   ${t.title}',
        for (final c in t.checklist) '   ${c.done ? '☑' : '☐'} ${c.text}${c.comment.isNotEmpty ? ' – ${c.comment}' : ''}',
        if (clients[t.clientId]?.hasLocation ?? false) '   ${maps(clients[t.clientId]!)}',
      ],
      if (open.any((t) => !t.isVisit)) ...['', l10n.tasks, for (final t in open.where((t) => !t.isVisit)) '• ${t.title}${t.done ? ' ✓' : ''}'],
      // Google Maps route through the stops (it accepts up to 9 waypoints).
      if (located.length > 1) ...[
        '',
        l10n.route,
        'https://www.google.com/maps/dir/?api=1&destination=${located.last.lat},${located.last.lng}'
            '&waypoints=${located.take(located.length - 1).take(9).map((c) => '${c.lat},${c.lng}').join('%7C')}',
      ],
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n'), subject: lines.first));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final owner = (ref.watch(usersProvider).value ?? const <AppUser>[]).where((u) => u.id == widget.userId).firstOrNull;
    if (me == null || owner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = dayKey(_day);
    final tasks = ref.watch(dayTasksProvider((owner.id, day)));
    final list = tasks.value ?? const <PlanTask>[];
    final isOwner = owner.id == me.id;
    final canManage = me.role.isSupervisor;
    final repo = ref.read(planRepositoryProvider);
    final pendingCount = list.where((t) => t.approval == TaskApproval.pending).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? l10n.myPlan : l10n.planOf(owner.name)),
        actions: [
          if (list.any((t) => t.isVisit))
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n.showOnMap,
              onPressed: () => context.push('/plan/${owner.id}/map?date=$day'),
            ),
          if (list.isNotEmpty)
            IconButton(icon: const Icon(Icons.share), tooltip: l10n.share, onPressed: () => _share(owner, list)),
          // Sales exec: only while something is not yet approved. KAM / manager: always.
          if (canManage ? list.isNotEmpty : isOwner && list.any((t) => t.approval != TaskApproval.approved))
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: l10n.clear,
              onPressed: () => _clear(me, owner, list, canManage),
            ),
        ],
      ),
      floatingActionButton: isOwner || canManage
          ? FloatingActionButton.extended(
              onPressed: () => showAddTaskSheet(
                context,
                owner: owner,
                date: day,
                alreadyPlanned: {for (final t in list) if (t.clientId != null) t.clientId!},
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addToPlan),
            )
          : null,
      body: Column(
        children: [
          DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
          if (canManage && pendingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.done_all),
                label: Text(l10n.approveAll(pendingCount)),
                onPressed: () async {
                  final n = await repo.approveAll(list, me.id);
                  await _notifyOwner(me, owner, NotificationType.planApproved, n);
                },
              ),
            ),
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
              data: (list) {
                if (list.isEmpty) return Center(child: Text(l10n.nothingPlanned));
                final approved = list.where((t) => t.approval == TaskApproval.approved).toList();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(l10n.planSummary(
                        approved.where((t) => t.done).length,
                        approved.length,
                        list.where((t) => t.approval == TaskApproval.pending).length,
                      )),
                    ),
                    for (final t in list)
                      PlanTaskTile(
                        task: t,
                        canTick: isOwner && t.approval == TaskApproval.approved,
                        canApprove: canManage && t.approval == TaskApproval.pending,
                        canDelete: canManage || (isOwner && t.approval != TaskApproval.approved),
                        onTick: (v) => repo.setDone(t.id, v),
                        onApprove: (a) async {
                          await repo.setApproval(t.id, a, me.id);
                          await _notifyOwner(me, owner,
                              a == TaskApproval.approved ? NotificationType.planApproved : NotificationType.planRejected, 1);
                        },
                        onDelete: () async {
                          await repo.delete(t.id);
                          if (canManage && !isOwner) await _notifyOwner(me, owner, NotificationType.planChanged, 1);
                        },
                        onVisit: isOwner && t.isVisit && !t.done && t.approval == TaskApproval.approved
                            ? () => context.push('/clients/${t.clientId}/visit')
                            : null,
                        onEdit: canManage ? () => _editTitle(me, owner, t) : null,
                        canTickChecklist: isOwner && t.approval == TaskApproval.approved,
                        canEditChecklist: (isOwner || canManage) && t.approval != TaskApproval.rejected,
                        onChecklistChanged: (items) async {
                          await repo.setChecklist(t.id, items);
                          final added = items.length - t.checklist.length;
                          if (!isOwner && added > 0) await _notifyOwner(me, owner, NotificationType.planChanged, added);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Previous / next day arrows around the date, which opens a date picker.
class DayBar extends StatelessWidget {
  const DayBar({super.key, required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onChanged(picked);
            },
            child: Text(
              dayKey(day) == dayKey(DateTime.now()) ? l10n.today : DateFormat.yMMMEd(locale).format(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(day.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}

/// One plan item, also used in the dashboard's approvals card. Client visits
/// show whether the client has a location (tap the pin to see it).
class PlanTaskTile extends ConsumerWidget {
  const PlanTaskTile({
    super.key,
    required this.task,
    this.canTick = false,
    this.canApprove = false,
    this.canDelete = false,
    this.onTick,
    this.onApprove,
    this.onDelete,
    this.onVisit,
    this.onEdit,
    this.subtitlePrefix,
    this.canTickChecklist = false,
    this.canEditChecklist = false,
    this.onChecklistChanged,
  });

  final PlanTask task;
  final bool canTick;
  final bool canApprove;
  final bool canDelete;
  final ValueChanged<bool>? onTick;
  final ValueChanged<TaskApproval>? onApprove;
  final VoidCallback? onDelete;
  final VoidCallback? onVisit;

  /// Tap to edit the note (KAM / managers).
  final VoidCallback? onEdit;

  /// e.g. the owner's name in the approvals list.
  final String? subtitlePrefix;

  /// A visit's task checklist: the owner ticks, the owner / KAM / managers add.
  final bool canTickChecklist;
  final bool canEditChecklist;
  final ValueChanged<List<ChecklistItem>>? onChecklistChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final client = task.isVisit
        ? ref.watch(allClientsProvider).value?.where((c) => c.id == task.clientId).firstOrNull
        : null;
    final status = switch (task.approval) {
      TaskApproval.pending => (l10n.waitingApproval, Colors.orange.shade800),
      TaskApproval.rejected => (l10n.rejected, scheme.error),
      TaskApproval.approved => task.done ? (l10n.done, Colors.green.shade700) : (l10n.toDo, scheme.onSurfaceVariant),
    };
    final title = task.isVisit ? task.clientName ?? '' : task.title;
    final note = task.isVisit ? task.title : '';

    final Widget leading = canTick && !task.isVisit
        ? Checkbox(value: task.done, onChanged: (v) => onTick?.call(v ?? false))
        : Icon(
            task.isVisit ? Icons.store : Icons.checklist,
            color: task.done ? Colors.green.shade700 : scheme.onSurfaceVariant,
          );

    final tile = ListTile(
      onTap: onEdit,
      leading: leading,
      title: Text(
        title,
        style: task.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitlePrefix != null) Text(subtitlePrefix!),
          if (note.isNotEmpty) Text(note),
          Text.rich(TextSpan(children: [
            TextSpan(text: status.$1, style: TextStyle(color: status.$2, fontWeight: FontWeight.w600)),
            if (task.checklist.isNotEmpty)
              TextSpan(
                text: ' · ${l10n.checklistProgress(task.checklistDone, task.checklist.length)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            if (client != null && !client.hasLocation)
              TextSpan(text: ' · ${l10n.noLocation}', style: TextStyle(color: scheme.onSurfaceVariant)),
          ])),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (client != null) ClientLocationButton(client: client),
          if (onVisit != null)
            IconButton(icon: const Icon(Icons.add_location_alt), tooltip: l10n.addVisit, onPressed: onVisit),
          if (canApprove) ...[
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green.shade700),
              tooltip: l10n.approve,
              onPressed: () => onApprove?.call(TaskApproval.approved),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: scheme.error),
              tooltip: l10n.reject,
              onPressed: () => onApprove?.call(TaskApproval.rejected),
            ),
          ],
          if (canDelete && onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: onDelete),
        ],
      ),
    );
    final editable = canEditChecklist && onChecklistChanged != null;
    if (!task.isVisit || (task.checklist.isEmpty && !editable)) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 40, bottom: 4),
          child: PlanChecklist(
            task: task,
            canTick: canTickChecklist && onChecklistChanged != null,
            canEdit: editable,
            onChanged: onChecklistChanged,
          ),
        ),
      ],
    );
  }
}
