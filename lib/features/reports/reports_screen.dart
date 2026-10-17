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
import '../home/dashboard_cards.dart';
import '../home/stats.dart';
import '../home/stats_widgets.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import 'report.dart';
import 'reports_data.dart';

enum _Period { thisMonth, lastMonth, custom }

/// Web dashboard (also on phones from More): a table of the team's numbers
/// for a period, the clients nobody visited in it, and the latest imports.
/// KAMs see their team, managers / GM all field staff.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Period _period = _Period.thisMonth;
  StatsRange _range = StatsRange.month(DateTime.now());

  /// null = the whole team.
  String? _person;

  /// null = all categories.
  String? _category;
  bool _showAllUnvisited = false;

  Future<void> _setPeriod(_Period period) async {
    final now = DateTime.now();
    if (period != _Period.custom) {
      setState(() {
        _period = period;
        _range = StatsRange.month(period == _Period.thisMonth ? now : DateTime(now.year, now.month - 1));
      });
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
    );
    if (picked != null) {
      setState(() {
        _period = _Period.custom;
        _range = StatsRange(picked.start, picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final team = [if (me.role.isTracked) me, ...teamOf(me, users)];
    if (_person != null && !team.any((u) => u.id == _person)) _person = null;
    final people = _person == null ? team : team.where((u) => u.id == _person).toList();

    final key = (null, _range.months.join(','));
    // Hidden clients are left out of every number.
    final hidden = ref.watch(hiddenClientIdsProvider);
    final visits = (ref.watch(rangeVisitsProvider(key)).value ?? const <Visit>[])
        .where((v) => !hidden.contains(v.clientId))
        .toList();
    final tasks = (ref.watch(rangeTasksProvider(key)).value ?? const <PlanTask>[])
        .where((t) => !hidden.contains(t.clientId))
        .toList();
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;

    final reports = buildReports(
      people: people,
      clients: clients,
      visits: visits,
      tasks: tasks,
      range: _range,
      rules: rules,
      now: now,
    );
    final unvisited = unvisitedClients(
      clients: clients.where((c) => _category == null || c.category == _category).toList(),
      ownerIds: {for (final u in people) u.id},
      visits: visits,
      range: _range,
    );
    final rangeLabel = _period == _Period.custom
        ? '${DateFormat.yMMMd(locale).format(_range.start)} – ${DateFormat.yMMMd(locale).format(_range.end)}'
        : DateFormat.yMMMM(locale).format(_range.start);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (period, label) in [
                (_Period.thisMonth, l10n.thisMonth),
                (_Period.lastMonth, l10n.lastMonth),
                (_Period.custom, _period == _Period.custom ? rangeLabel : l10n.customRange),
              ])
                ChoiceChip(
                  label: Text(label),
                  avatar: period == _Period.custom ? const Icon(Icons.date_range, size: 18) : null,
                  selected: _period == period,
                  onSelected: (_) => _setPeriod(period),
                ),
              if (team.length > 1)
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
          Text(rangeLabel, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _Section(
            title: l10n.teamPerformance,
            icon: Icons.groups,
            child: _TeamTable(
              reports: reports,
              range: _range,
              onSelect: (id) => setState(() => _person = id),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final unvisitedCard = _Section(
              title: l10n.unvisitedInPeriod(unvisited.length),
              icon: Icons.store_mall_directory_outlined,
              trailing: Wrap(spacing: 4, children: [
                for (final cat in [null, ...clientCategories])
                  ChoiceChip(
                    label: Text(cat ?? l10n.statusAll),
                    selected: _category == cat,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _category = cat),
                  ),
              ]),
              child: _UnvisitedList(
                clients: unvisited,
                users: {for (final u in users) u.id: u},
                rules: rules,
                showAll: _showAllUnvisited,
                onShowAll: () => setState(() => _showAllUnvisited = true),
              ),
            );
            if (!me.role.isAdmin) return unvisitedCard;
            const imports = _ImportsCard();
            if (c.maxWidth < 900) return Column(children: [unvisitedCard, const SizedBox(height: 12), imports]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: unvisitedCard),
                const SizedBox(width: 12),
                const Expanded(flex: 2, child: imports),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child, this.trailing});

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: theme.textTheme.titleMedium),
                ]),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _ratio(int done, int total) => total == 0 ? '–' : '$done/$total · ${(100 * done / total).round()}%';

/// One row per person, sortable by any column, with a total row.
class _TeamTable extends StatefulWidget {
  const _TeamTable({required this.reports, required this.range, required this.onSelect});

  final List<PersonReport> reports;
  final StatsRange range;
  final ValueChanged<String> onSelect;

  @override
  State<_TeamTable> createState() => _TeamTableState();
}

class _TeamTableState extends State<_TeamTable> {
  int _sortColumn = 1;
  bool _ascending = false;

  static final _sortKeys = <Comparable<Object> Function(PersonReport)>[
    (r) => r.user.name.toLowerCase(),
    (r) => r.contacts,
    (r) => r.clientsVisited,
    (r) => r.coverage ?? -1,
    (r) => r.assigned == 0 ? -1 : r.onSchedule / r.assigned,
    (r) => r.planCompletion ?? -1,
    (r) => r.withKam,
    (r) => r.flagged,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.reports.isEmpty) {
      return Text(l10n.noTrackedStaff, style: theme.textTheme.bodyMedium);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = today.isBefore(widget.range.end) ? today : widget.range.end;
    double expected(AppUser u) =>
        widget.range.start.isAfter(today) ? 0 : targetFor(u.monthlyTarget, widget.range, until: until);

    final rows = [...widget.reports]..sort((a, b) {
        final c = _sortKeys[_sortColumn](a).compareTo(_sortKeys[_sortColumn](b));
        return _ascending ? c : -c;
      });
    int sum(int Function(PersonReport) f) => rows.fold(0, (s, r) => s + f(r));
    final target = rows.fold<double>(0, (s, r) => s + r.target);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    void sort(int column, bool ascending) => setState(() {
          _sortColumn = column;
          _ascending = ascending;
        });
    DataColumn column(String label, {bool numeric = true}) =>
        DataColumn(label: Text(label), numeric: numeric, onSort: sort);

    Widget visitsCell(PersonReport r) {
      final text = Text([visitsAndCallsText(r.visits, r.calls), if (r.target > 0) '${r.target.round()}'].join('/'));
      if (r.target <= 0) return text;
      final (icon, color, label) = paceStyle(paceOf(r.contacts, expected(r.user)), l10n);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Tooltip(message: label, child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 6),
        text,
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumn,
        sortAscending: _ascending,
        showCheckboxColumn: false,
        columnSpacing: 28,
        columns: [
          column(l10n.person, numeric: false),
          column(l10n.visitsPlusCalls),
          column(l10n.clientsVisitedColumn),
          column(l10n.ownClientsVisited),
          column(l10n.onSchedule),
          column(l10n.planCompletion),
          column(l10n.rideAlongs),
          column(l10n.flaggedVisits),
          const DataColumn(label: SizedBox.shrink()),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              onSelectChanged: (_) => widget.onSelect(r.user.id),
              cells: [
                DataCell(Text(r.user.name)),
                DataCell(visitsCell(r)),
                DataCell(Text('${r.clientsVisited}')),
                DataCell(Text(_ratio(r.assignedVisited, r.assigned))),
                DataCell(Text(_ratio(r.onSchedule, r.assigned))),
                DataCell(Text(_ratio(r.tasksDone, r.tasksApproved))),
                DataCell(Text('${r.withKam}')),
                DataCell(Text(
                  '${r.flagged}',
                  style: r.flagged > 0 ? TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold) : null,
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: l10n.openPlan,
                    icon: const Icon(Icons.today, size: 20),
                    onPressed: () => context.push('/plan/${r.user.id}'),
                  ),
                  IconButton(
                    tooltip: l10n.routeHistory,
                    icon: const Icon(Icons.route, size: 20),
                    onPressed: () => context.go('/history?uid=${r.user.id}'),
                  ),
                ])),
              ],
            ),
          if (rows.length > 1)
            DataRow(cells: [
              DataCell(Text(l10n.everyone, style: bold)),
              DataCell(Text(
                [visitsAndCallsText(sum((r) => r.visits), sum((r) => r.calls)), if (target > 0) '${target.round()}']
                    .join('/'),
                style: bold,
              )),
              DataCell(Text('${sum((r) => r.clientsVisited)}', style: bold)),
              DataCell(Text(_ratio(sum((r) => r.assignedVisited), sum((r) => r.assigned)), style: bold)),
              DataCell(Text(_ratio(sum((r) => r.onSchedule), sum((r) => r.assigned)), style: bold)),
              DataCell(Text(_ratio(sum((r) => r.tasksDone), sum((r) => r.tasksApproved)), style: bold)),
              DataCell(Text('${sum((r) => r.withKam)}', style: bold)),
              DataCell(Text('${sum((r) => r.flagged)}', style: bold)),
              const DataCell(SizedBox.shrink()),
            ]),
        ],
      ),
    );
  }
}

class _UnvisitedList extends StatelessWidget {
  const _UnvisitedList({
    required this.clients,
    required this.users,
    required this.rules,
    required this.showAll,
    required this.onShowAll,
  });

  static const _initialCount = 15;

  final List<Client> clients;
  final Map<String, AppUser> users;
  final VisitRules rules;
  final bool showAll;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (clients.isEmpty) return Text(l10n.allClientsVisited);
    final now = DateTime.now();
    final shown = showAll ? clients : clients.take(_initialCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in shown)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: visitStatusColor(visitStatus(c, rules, now)),
              child: Text(c.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [users[c.assignedTo]?.name, if (c.city.isNotEmpty) c.city].nonNulls.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(c.lastVisitAt == null ? l10n.never : l10n.daysAgo(now.difference(c.lastVisitAt!).inDays)),
            onTap: () => context.go('/clients/${c.id}'),
          ),
        if (!showAll && clients.length > _initialCount)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: onShowAll, child: Text(l10n.showAllCount(clients.length))),
          ),
      ],
    );
  }
}

/// Latest client imports (sales manager / GM).
class _ImportsCard extends ConsumerWidget {
  const _ImportsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final batches = ref.watch(importBatchesProvider);
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    return _Section(
      title: l10n.importHistory,
      icon: Icons.upload_file,
      child: batches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(l10n.errorWithMessage('$e')),
        data: (list) => list.isEmpty
            ? Text(l10n.noImports)
            : Column(children: [
                for (final b in list)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: statusGood.withValues(alpha: 0.15),
                      child: Text('+${b.added}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(b.fileName.isEmpty ? '–' : b.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      l10n.importBatchLine(b.added, b.updated, b.unchanged),
                      if (b.createdAt != null) DateFormat.yMMMd(locale).add_jm().format(b.createdAt!),
                      if (users[b.importedBy] case final u?) l10n.importedByName(u.name),
                    ].join(' · ')),
                  ),
              ]),
      ),
    );
  }
}
