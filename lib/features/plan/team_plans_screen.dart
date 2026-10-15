import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../home/dashboard_cards.dart';
import '../notifications/notifications.dart';
import '../users/users_repository.dart';
import 'plan_repository.dart';
import 'plan_screen.dart';
import 'plan_task.dart';

/// Everyone's plan for one day on one page (KAM: own team; managers / GM:
/// all field staff). People with a plan come first; any item can be deleted
/// here (approved ones too); tap a person to open their plan for that day to
/// approve, edit or add.
class TeamPlansScreen extends ConsumerStatefulWidget {
  const TeamPlansScreen({super.key, this.initialDate});

  /// 'yyyy-MM-dd'; today when null.
  final String? initialDate;

  @override
  ConsumerState<TeamPlansScreen> createState() => _TeamPlansScreenState();
}

class _TeamPlansScreenState extends ConsumerState<TeamPlansScreen> {
  late DateTime _day = DateTime.tryParse(widget.initialDate ?? '') ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final team = teamOf(me, ref.watch(usersProvider).value ?? const <AppUser>[]);
    final day = dayKey(_day);
    final tasks = ref.watch(teamDayTasksProvider(day));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.teamPlans)),
      body: Column(
        children: [
          DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
          Expanded(
            child: tasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
              data: (all) {
                if (team.isEmpty) return Center(child: Text(l10n.noTeamMembers));
                final byOwner = <String, List<PlanTask>>{};
                for (final t in all) {
                  (byOwner[t.ownerId] ??= []).add(t);
                }
                // People with a plan first, then by name.
                final people = [...team]..sort((a, b) {
                    final planned = (byOwner[a.id] == null ? 1 : 0).compareTo(byOwner[b.id] == null ? 1 : 0);
                    return planned != 0 ? planned : a.name.compareTo(b.name);
                  });
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    for (final u in people) _PersonPlan(me: me, user: u, day: day, tasks: byOwner[u.id] ?? const []),
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

class _PersonPlan extends ConsumerWidget {
  const _PersonPlan({required this.me, required this.user, required this.day, required this.tasks});

  final AppUser me;
  final AppUser user;
  final String day;
  final List<PlanTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final approved = tasks.where((t) => t.approval == TaskApproval.approved).toList();
    final done = approved.where((t) => t.done).length;
    final pending = tasks.where((t) => t.approval == TaskApproval.pending).length;
    void open() => context.push('/plan/${user.id}?date=$day');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(user.name.isEmpty ? '?' : user.name.characters.first)),
              title: Text(user.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(tasks.isEmpty ? l10n.nothingPlanned : l10n.planSummary(done, approved.length, pending)),
              trailing: pending > 0
                  ? Badge(label: Text('$pending'), child: const Icon(Icons.chevron_right))
                  : const Icon(Icons.chevron_right),
              onTap: open,
            ),
            if (approved.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(value: done / approved.length),
              ),
            for (final t in tasks)
              PlanTaskTile(
                task: t,
                onEdit: open,
                canDelete: true,
                onDelete: () async {
                  await ref.read(planRepositoryProvider).delete(t.id);
                  await sendNotifications(
                    toIds: [user.id],
                    type: NotificationType.planChanged,
                    fromId: me.id,
                    ownerId: user.id,
                    date: day,
                    count: 1,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
