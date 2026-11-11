import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/city_areas.dart';
import '../../core/providers.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../../l10n/app_localizations.dart';
import '../home/dashboard_cards.dart';
import '../notifications/notifications.dart';
import '../users/people_filter.dart' show territoryRegionsProvider;
import '../users/users_repository.dart';
import 'add_task_sheet.dart';
import 'plan_repository.dart';
import 'plan_screen.dart';
import 'plan_task.dart';
import 'route_order.dart';

/// The region picked on Team plans, shared with its map (user 2026-11-11:
/// the map key keeps the same filter). Null = everywhere.
final teamPlanRegionProvider = NotifierProvider<TeamPlanRegion, SaudiRegion?>(TeamPlanRegion.new);

class TeamPlanRegion extends Notifier<SaudiRegion?> {
  @override
  SaudiRegion? build() => null;

  void set(SaudiRegion? r) => state = r;
}

/// Whether a person's day belongs to [region]: a planned visit (picked
/// location, else the main one) inside it — the stops the map keeps — or,
/// with no located visit that day, their clients' region.
bool planInRegion(SaudiRegion? region, List<PlanTask> tasks, Map<String, Client> clients, SaudiRegion? territory) {
  if (region == null) return true;
  final stops = [
    for (final t in tasks)
      if (t.isVisit && t.approval != TaskApproval.rejected) ?planStop(t, clients),
  ];
  if (stops.isNotEmpty) return stops.any((p) => region.contains(p.lat, p.lng));
  return territory == region;
}

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
    final region = ref.watch(teamPlanRegionProvider);
    final clients = ref.watch(clientsByIdProvider);
    final territory = ref.watch(territoryRegionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamPlans),
        actions: [
          // Everyone's visits of the day on one map.
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.showOnMap,
            // Same region as here (shared provider).
            onPressed: () => context.push('/team-plans/map?date=$day'),
          ),
        ],
      ),
      body: Column(
        children: [
          DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: RegionChips(
                  fill: true,
                  selected: region,
                  onSelected: ref.read(teamPlanRegionProvider.notifier).set,
                ),
              ),
            ),
          ),
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
                // People with a plan first, then by name; a region keeps those
                // whose day is there.
                final people = [
                  for (final u in team)
                    if (planInRegion(region, byOwner[u.id] ?? const [], clients, territory[u.id])) u,
                ]..sort((a, b) {
                    final planned = (byOwner[a.id] == null ? 1 : 0).compareTo(byOwner[b.id] == null ? 1 : 0);
                    return planned != 0 ? planned : a.name.compareTo(b.name);
                  });
                if (people.isEmpty) return Center(child: Text(l10n.noOneMatches));
                // A grid on wide screens (user 2026-11-11: the middle was
                // empty): 3 columns from 900 px, 4 from 1300 px. Cards differ
                // in height, so each goes to the shortest column (by item
                // count), in order.
                return LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 1300
                      ? 4
                      : c.maxWidth >= 900
                          ? 3
                          : c.maxWidth >= 600
                              ? 2
                              : 1;
                  Widget card(AppUser u) => _PersonPlan(me: me, user: u, day: day, tasks: byOwner[u.id] ?? const []);
                  if (cols == 1) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [for (final u in people) card(u)],
                    );
                  }
                  final columns = [for (var i = 0; i < cols; i++) <AppUser>[]];
                  final heights = List.filled(cols, 0);
                  for (final u in people) {
                    var best = 0;
                    for (var i = 1; i < cols; i++) {
                      if (heights[i] < heights[best]) best = i;
                    }
                    columns[best].add(u);
                    heights[best] += 2 + (byOwner[u.id]?.length ?? 0);
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, list) in columns.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: Column(children: [for (final u in list) card(u)])),
                        ],
                      ],
                    ),
                  );
                });
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

    // A clear shadow separates the salespeople's cards (user request 2026-11-11).
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(user.name.isEmpty ? '?' : user.name.characters.first)),
              title: Text(user.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(tasks.isEmpty ? l10n.nothingPlanned : l10n.planSummary(done, approved.length, pending)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Added items are approved and the owner is notified.
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    tooltip: l10n.addToPlan,
                    onPressed: () => showAddTaskSheet(
                      context,
                      owner: user,
                      date: day,
                      alreadyPlanned: {for (final t in tasks) if (t.clientId != null) t.clientId!},
                    ),
                  ),
                  if (pending > 0)
                    Badge(label: Text('$pending'), child: const Icon(Icons.chevron_right))
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
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
                canEditChecklist: t.approval != TaskApproval.rejected,
                onChecklistChanged: (items) async {
                  await ref.read(planRepositoryProvider).setChecklist(t.id, items);
                  final added = items.length - t.checklist.length;
                  if (added <= 0) return;
                  await sendNotifications(
                    toIds: [user.id],
                    type: NotificationType.planChanged,
                    fromId: me.id,
                    ownerId: user.id,
                    date: day,
                    count: added,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
