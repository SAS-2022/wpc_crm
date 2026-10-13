import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notifications.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_screen.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';

class _DashCard extends StatelessWidget {
  const _DashCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                  ?action,
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}

/// Today's plan of [user]: done vs. pending, with a link to the full plan.
class TodayPlanCard extends ConsumerWidget {
  const TodayPlanCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(dayTasksProvider((user.id, dayKey(DateTime.now())))).value ?? const <PlanTask>[];
    final approved = tasks.where((t) => t.approval == TaskApproval.approved).toList();
    final repo = ref.read(planRepositoryProvider);
    return _DashCard(
      title: l10n.todaysPlan,
      action: TextButton(onPressed: () => context.push('/plan/${user.id}'), child: Text(l10n.openPlan)),
      child: tasks.isEmpty
          ? Text(l10n.nothingPlanned)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.planSummary(
                  approved.where((t) => t.done).length,
                  approved.length,
                  tasks.where((t) => t.approval == TaskApproval.pending).length,
                )),
                if (approved.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: approved.where((t) => t.done).length / approved.length),
                ],
                for (final t in tasks.take(5))
                  PlanTaskTile(
                    task: t,
                    canTick: t.approval == TaskApproval.approved,
                    onTick: (v) => repo.setDone(t.id, v),
                    onVisit: t.isVisit && !t.done && t.approval == TaskApproval.approved
                        ? () => context.push('/clients/${t.clientId}/visit')
                        : null,
                  ),
                if (tasks.length > 5) Text('+${tasks.length - 5}', textAlign: TextAlign.center),
              ],
            ),
    );
  }
}

/// The people [me] supervises: KAM → own team; managers / GM → all field staff.
List<AppUser> teamOf(AppUser me, List<AppUser> users) => users
    .where((u) => u.active && u.role.isTracked && u.id != me.id)
    .where((u) => me.role != UserRole.kam || u.kamId == me.id)
    .toList();

/// Tasks waiting for [me]'s approval.
class ApprovalsCard extends ConsumerWidget {
  const ApprovalsCard({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final team = {for (final u in teamOf(me, users)) u.id: u};
    final pending = (ref.watch(pendingTasksProvider).value ?? const <PlanTask>[])
        .where((t) => team.containsKey(t.ownerId))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (pending.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(planRepositoryProvider);
    final locale = Localizations.localeOf(context).toString();
    return _DashCard(
      title: l10n.waitingForYourApproval(pending.length),
      child: Column(
        children: [
          for (final t in pending)
            PlanTaskTile(
              task: t,
              canApprove: true,
              subtitlePrefix: '${team[t.ownerId]!.name} · ${DateFormat.MMMEd(locale).format(DateTime.parse(t.date))}',
              onApprove: (a) async {
                await repo.setApproval(t.id, a, me.id);
                await sendNotifications(
                  toIds: [t.ownerId],
                  type: a == TaskApproval.approved ? NotificationType.planApproved : NotificationType.planRejected,
                  fromId: me.id,
                  ownerId: t.ownerId,
                  date: t.date,
                  count: 1,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Each team member's plan for today; tap to open it (any day from there).
class TeamPlansCard extends ConsumerWidget {
  const TeamPlansCard({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final team = teamOf(me, ref.watch(usersProvider).value ?? const <AppUser>[]);
    if (team.isEmpty) return const SizedBox.shrink();
    final tasks = ref.watch(teamDayTasksProvider(dayKey(DateTime.now()))).value ?? const <PlanTask>[];
    return _DashCard(
      title: l10n.teamPlansToday,
      child: Column(
        children: [
          for (final u in team)
            Builder(builder: (context) {
              final mine = tasks.where((t) => t.ownerId == u.id).toList();
              final approved = mine.where((t) => t.approval == TaskApproval.approved).toList();
              final done = approved.where((t) => t.done).length;
              final pending = mine.where((t) => t.approval == TaskApproval.pending).length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(u.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mine.isEmpty ? l10n.nothingPlanned : l10n.planSummary(done, approved.length, pending)),
                    if (approved.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: done / approved.length),
                    ],
                  ],
                ),
                trailing: pending > 0
                    ? Badge(label: Text('$pending'), child: const Icon(Icons.chevron_right))
                    : const Icon(Icons.chevron_right),
                onTap: () => context.push('/plan/${u.id}'),
              );
            }),
        ],
      ),
    );
  }
}
