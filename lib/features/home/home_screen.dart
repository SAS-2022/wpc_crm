import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/skeleton.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../notifications/notifications_screen.dart';
import '../plan/plan_task.dart';
import '../tracking/tracking_card.dart';
import '../users/users_repository.dart';
import '../hr/leave_rules.dart' show myLeaveEnabled;
import '../hr/leave_widgets.dart';
import '../visits/call_chip.dart';
import '../visits/visit.dart';
import 'dashboard_cards.dart';
import 'progress_charts.dart';
import 'stats.dart';
import 'stats_widgets.dart';
import '../attendance/absence_screen.dart' show PendingAbsencesCard;
import '../attendance/early_checkout_card.dart';
import '../settings/page_access.dart';
import '../attendance/attendance_card.dart';
import '../attendance/attendance_calendar_view.dart';

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
    if (me.role.isBackOffice) return _BackOfficeHome(me: me);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Who the numbers are about.
    final usersAsync = ref.watch(usersProvider);
    final users = usersAsync.value ?? const <AppUser>[];
    final team = me.role.isSupervisor
        ? [if (me.role.isTracked) me, ...teamOf(me, users)]
        : [me];
    if (_person != null && !team.any((u) => u.id == _person)) _person = null;
    final people = _person == null ? team : team.where((u) => u.id == _person).toList();
    final ids = {for (final u in people) u.id};

    // Sales execs may only query their own documents.
    final key = (me.role.isSupervisor ? null : me.id, _range.months.join(','));
    // Hidden clients are left out of every number.
    final hidden = ref.watch(hiddenClientIdsProvider);
    final visitsAsync = ref.watch(rangeVisitsProvider(key));
    final rangeVisits = (visitsAsync.value ?? const <Visit>[])
        .where((v) => v.checkedInAt != null && _range.contains(v.checkedInAt!) && !hidden.contains(v.clientId))
        .toList();
    // Visits and calls of the people shown; calls count toward the target
    // but are shown apart ("190 + 30 / 240").
    final mineAll = rangeVisits.where((v) => ids.contains(v.salesExecId)).toList();
    final visits = mineAll.where((v) => !v.isCall).toList();
    final calls = mineAll.where((v) => v.isCall).toList();
    final contacts = mineAll.length;
    final tasksAsync = ref.watch(rangeTasksProvider(key));
    final tasks = (tasksAsync.value ?? const <PlanTask>[])
        .where((t) => ids.contains(t.ownerId) && _range.contains(DateTime.parse(t.date)) && !hidden.contains(t.clientId))
        .toList();
    final clientsAsync = ref.watch(workingClientsProvider);
    final allClients = clientsAsync.value ?? const <Client>[];
    // First load (e.g. the web page refreshed): placeholders instead of
    // zeros until the numbers' data has come (an error doesn't keep them).
    final loading = [usersAsync, visitsAsync, tasksAsync, clientsAsync].any((a) => a.isLoading && !a.hasValue);
    final clients = allClients.where((c) => c.hasLocation && ids.contains(c.assignedTo)).toList();

    // Targets for the period, and what was expected by today.
    final until = today.isBefore(_range.end) ? today : _range.end;
    double rangeTarget(AppUser u) => targetFor(u.monthlyTarget, _range);
    double expectedTarget(AppUser u) => _range.start.isAfter(today) ? 0 : targetFor(u.monthlyTarget, _range, until: until);
    final target = people.fold<double>(0, (s, u) => s + rangeTarget(u));
    final expected = people.fold<double>(0, (s, u) => s + expectedTarget(u));

    final approved = tasks.where((t) => t.approval == TaskApproval.approved).toList();
    final tasksDone = approved.where((t) => t.done).length;
    final flagged = visits.where((v) => v.isFlagged).length;
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
          // Assigned to a work site: today's check-in / check-out.
          AttendanceCard(me: me),
          // Leave requests waiting for this person's approval (hidden when none).
          const LeaveApprovalsCard(),
          // HR / GM: reported absences to decide (hidden when none).
          const PendingAbsencesCard(),
          // Direct managers: today's requests to leave early (hidden when none).
          const EarlyCheckoutRequestsCard(),
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
          if (loading) const _DashboardSkeleton() else ...[
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth > 720 ? 4 : 2;
            final width = (c.maxWidth - 8 * (columns - 1)) / columns;
            final tiles = [
              StatTile(
                icon: Icons.event_available,
                label: l10n.visits,
                value: [visitsAndCallsText(visits.length, calls.length), if (target > 0) '${target.round()}'].join('/'),
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (calls.isNotEmpty)
                      Text(l10n.visitsAndCallsDetail(visits.length, calls.length),
                          style: theme.textTheme.bodySmall?.copyWith(color: callColor)),
                    if (target > 0) ...[
                      // Visits (blue) then calls (purple) toward the target.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Stack(children: [
                            Container(color: theme.colorScheme.surfaceContainerHighest),
                            FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: (contacts / target).clamp(0, 1).toDouble(),
                                child: Container(color: callColor)),
                            FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: (visits.length / target).clamp(0, 1).toDouble(),
                                child: Container(color: seriesBlue)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      PaceLabel(pace: paceOf(contacts, expected)),
                    ] else
                      Text(l10n.noTargetSet, style: theme.textTheme.bodySmall),
                  ],
                ),
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
                            calls: calls.where((v) => v.salesExecId == u.id).length,
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
                      callDays: [for (final v in calls) v.checkedInAt!],
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
          ],
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

/// The numbers' shape while their data loads: four tiles, the target
/// chart and the two cards under it (side by side on wide screens).
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile(double width) => SizedBox(
          width: width,
          child: const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [SkeletonBox(width: 20, height: 20, radius: 10), SizedBox(width: 8), SkeletonBox(width: 70, height: 12)]),
                  SizedBox(height: 14),
                  SkeletonBox(width: 64, height: 26),
                  SizedBox(height: 12),
                  SkeletonBox(height: 8),
                ],
              ),
            ),
          ),
        );
    return Skeleton(
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final columns = c.maxWidth > 720 ? 4 : 2;
        final width = (c.maxWidth - 8 * (columns - 1)) / columns;
        const lower = [SkeletonCard(lines: 4), SkeletonCard(lines: 4)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < 4; i++) tile(width)]),
            const SizedBox(height: 12),
            const SkeletonCard(height: 160),
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: lower[0]), const SizedBox(width: 12), Expanded(child: lower[1])],
              )
            else ...[lower[0], const SizedBox(height: 12), lower[1]],
          ],
        );
      }),
    );
  }
}

/// Home for HR, accounting and procurement: no sales numbers. Attendance and
/// leave cards will go here.
class _BackOfficeHome extends ConsumerWidget {
  const _BackOfficeHome({required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.welcome(me.name)), actions: const [NotificationsBell()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(child: Text(me.name.isEmpty ? '?' : me.name.characters.first)),
              title: Text(me.name),
              subtitle: Text(me.role.label(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile'),
            ),
          ),
          const SizedBox(height: 12),
          // Drivers share their location like the sales team: permissions / phone health.
          if (me.role.isLocationTracked) const TrackingCard(),
          // Today's check-in (big Check in / Check out button) and the month calendar.
          AttendanceCard(me: me, prominent: true),
          if (me.checksAttendance) MyAttendanceCalendar(me: me),
          // HR: requests waiting for them first.
          const LeaveApprovalsCard(),
          const PendingAbsencesCard(),
          const EarlyCheckoutRequestsCard(),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              enabled: myLeaveEnabled,
              leading: const Icon(Icons.beach_access),
              title: Text(l10n.myLeave),
              subtitle: Text(myLeaveEnabled ? l10n.myLeaveHint : l10n.comingSoon),
              trailing: myLeaveEnabled ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
              onTap: () => context.push('/leave'),
            ),
          ),
          // Logistics manager / warehouse supervisor: the drivers' live map.
          if (me.role.seesDrivers &&
              (ref.watch(pageAccessProvider).value ?? PageAccess.defaults).allowsUser(me, AppPage.drivers)) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(l10n.driversPage),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/drivers'),
              ),
            ),
          ],
          if (me.role.canSeeHr) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.badge),
                title: Text(l10n.hrArea),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/hr'),
              ),
            ),
          ],

        ],
      ),
    );
  }
}
