import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../notifications/notifications_screen.dart';
import '../plan/plan_task.dart';
import '../tracking/tracking_card.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import '../visits/visits_repository.dart';
import 'dashboard_cards.dart';
import 'progress_charts.dart';
import 'stats.dart';
import 'stats_widgets.dart';

enum _RangeKind { thisMonth, lastMonth, custom }

/// Home tab: statistics for the selected period. Visits against the monthly
/// target (spread over the period), coverage, plan completion and flags,
/// a target chart, plan progress (done / to do / missed / waiting) and client
/// visits per salesperson. Sales execs see themselves, a KAM their team,
/// managers everyone; KAM / managers filter by person.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _RangeKind _kind = _RangeKind.thisMonth;
  StatsRange _range = StatsRange.month(DateTime.now());

  /// null = the whole team.
  String? _person;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
    );
    if (picked != null) {
      setState(() {
        _kind = _RangeKind.custom;
        _range = StatsRange(picked.start, picked.end);
      });
    }
  }

  void _setKind(_RangeKind kind) {
    if (kind == _RangeKind.custom) {
      _pickRange();
      return;
    }
    final now = DateTime.now();
    setState(() {
      _kind = kind;
      _range = StatsRange.month(kind == _RangeKind.thisMonth ? now : DateTime(now.year, now.month - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Who the numbers are about.
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final team = me.role.isSupervisor
        ? [if (me.role.isTracked) me, ...teamOf(me, users)]
        : [me];
    if (_person != null && !team.any((u) => u.id == _person)) _person = null;
    final people = _person == null ? team : team.where((u) => u.id == _person).toList();
    final ids = {for (final u in people) u.id};

    // Sales execs may only query their own documents.
    final key = (me.role.isSupervisor ? null : me.id, _range.months.join(','));
    final rangeVisits = (ref.watch(rangeVisitsProvider(key)).value ?? const <Visit>[])
        .where((v) => v.checkedInAt != null && _range.contains(v.checkedInAt!))
        .toList();
    final visits = rangeVisits.where((v) => ids.contains(v.salesExecId)).toList();
    final tasks = (ref.watch(rangeTasksProvider(key)).value ?? const <PlanTask>[])
        .where((t) => ids.contains(t.ownerId) && _range.contains(DateTime.parse(t.date)))
        .toList();
    final allClients = ref.watch(clientsProvider).value ?? const <Client>[];
    final clients = allClients.where((c) => c.hasLocation && ids.contains(c.assignedTo)).toList();

    // Targets for the period, and what was expected by today.
    final until = today.isBefore(_range.end) ? today : _range.end;
    double rangeTarget(AppUser u) => targetFor(u.monthlyTarget, _range);
    double expectedTarget(AppUser u) => _range.start.isAfter(today) ? 0 : targetFor(u.monthlyTarget, _range, until: until);
    final target = people.fold<double>(0, (s, u) => s + rangeTarget(u));
    final expected = people.fold<double>(0, (s, u) => s + expectedTarget(u));

    final approved = tasks.where((t) => t.approval == TaskApproval.approved).toList();
    final tasksDone = approved.where((t) => t.done).length;
    final flagged = visits.where((v) => v.mocked || (v.distanceMeters != null && v.distanceMeters! > visitRadiusMeters)).length;
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final green = clients.where((c) => visitStatus(c, rules, now) == VisitStatus.recent).length;

    final rangeLabel = switch (_kind) {
      _RangeKind.thisMonth || _RangeKind.lastMonth => DateFormat.yMMMM(locale).format(_range.start),
      _RangeKind.custom => '${DateFormat.MMMd(locale).format(_range.start)} – ${DateFormat.MMMd(locale).format(_range.end)}',
    };
    final single = people.length == 1 ? people.single : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.welcome(me.name)), actions: const [NotificationsBell()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          const TrackingCard(),
          // Filters: period and person, in one row above the numbers.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (kind, label) in [
                (_RangeKind.thisMonth, l10n.thisMonth),
                (_RangeKind.lastMonth, l10n.lastMonth),
                (_RangeKind.custom, _kind == _RangeKind.custom ? rangeLabel : l10n.customRange),
              ])
                ChoiceChip(
                  label: Text(label),
                  avatar: kind == _RangeKind.custom ? const Icon(Icons.date_range, size: 18) : null,
                  selected: _kind == kind,
                  onSelected: (_) => _setKind(kind),
                ),
              if (me.role.isSupervisor && team.length > 1)
                DropdownButton<String?>(
                  value: _person,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: null, child: Text(me.role == UserRole.kam ? l10n.myTeam : l10n.everyone)),
                    for (final u in team) DropdownMenuItem(value: u.id, child: Text(u.name)),
                  ],
                  onChanged: (v) => setState(() => _person = v),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            single == null ? rangeLabel : '${single.name} · $rangeLabel',
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth > 720 ? 4 : 2;
            final width = (c.maxWidth - 8 * (columns - 1)) / columns;
            final tiles = [
              StatTile(
                icon: Icons.event_available,
                label: l10n.visits,
                value: target > 0 ? '${visits.length}/${target.round()}' : '${visits.length}',
                footer: target > 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: (visits.length / target).clamp(0, 1),
                            color: seriesBlue,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 6),
                          PaceLabel(pace: paceOf(visits.length, expected)),
                        ],
                      )
                    : Text(l10n.noTargetSet, style: theme.textTheme.bodySmall),
              ),
              StatTile(
                icon: Icons.store,
                label: l10n.coverage,
                value: clients.isEmpty ? '–' : '${(100 * green / clients.length).round()}%',
                footer: Text(l10n.coverageDetail(green, clients.length), style: theme.textTheme.bodySmall),
              ),
              StatTile(
                icon: Icons.checklist,
                label: l10n.planCompletion,
                value: approved.isEmpty ? '–' : '${(100 * tasksDone / approved.length).round()}%',
                footer: Text(l10n.tasksDetail(tasksDone, approved.length), style: theme.textTheme.bodySmall),
              ),
              StatTile(
                icon: Icons.flag,
                label: l10n.flaggedVisits,
                value: '$flagged',
                footer: Text(l10n.flaggedDetail, style: theme.textTheme.bodySmall),
              ),
            ];
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tiles) SizedBox(width: width, child: t)],
            );
          }),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(single == null ? l10n.visitsVsTarget : l10n.progressVsTarget,
                            style: theme.textTheme.titleMedium),
                      ),
                      if (single != null && single.id != me.id)
                        TextButton.icon(
                          onPressed: () => context.push('/plan/${single.id}'),
                          icon: const Icon(Icons.today, size: 18),
                          label: Text(l10n.openPlan),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (single == null)
                    TargetBars(
                      rows: [
                        for (final u in people)
                          PersonProgress(
                            id: u.id,
                            name: u.name,
                            done: visits.where((v) => v.salesExecId == u.id).length,
                            target: rangeTarget(u),
                            expected: expectedTarget(u),
                          ),
                      ],
                      onSelect: (id) => setState(() => _person = id),
                    )
                  else
                    ProgressLine(
                      range: _range,
                      visitDays: [for (final v in visits) v.checkedInAt!],
                      monthlyTarget: single.monthlyTarget,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Side by side on wide screens (web), stacked on phones.
          LayoutBuilder(builder: (context, c) {
            void select(String id) => setState(() => _person = id);
            final cards = [
              PlanProgressCard(people: people, tasks: tasks, today: today, onSelect: select),
              ClientVisitsCard(people: people, clients: allClients, visits: rangeVisits, onSelect: select),
            ];
            if (c.maxWidth < 720) {
              return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])],
            );
          }),
          const SizedBox(height: 12),
          if (me.role.isSupervisor) ...[
            ApprovalsCard(me: me),
            TeamPlansCard(me: me),
          ],
          if (me.role.isTracked) TodayPlanCard(user: me),
        ],
      ),
    );
  }
}
