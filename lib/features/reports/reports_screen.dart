import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attendance/attendance_calendar.dart' show daysBetween;
import '../clients/client.dart';
import '../clients/client_tags.dart';
import '../clients/clients_repository.dart';
import '../clients/given_items.dart';
import '../clients/visit_rules.dart';
import '../home/dashboard_cards.dart';
import '../home/stats.dart';
import '../home/stats_widgets.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../tracking/work_hours.dart';
import '../plan/plan_task.dart';
import '../users/users_repository.dart';
import '../visits/visit.dart';
import 'report.dart';
import 'report_sections.dart';
import 'report_pdf.dart';
import 'report_ranking.dart';
import 'report_ranking_view.dart';
import 'report_sections_view.dart';
import 'reports_data.dart';

enum _Period { thisMonth, lastMonth, custom }

/// Web dashboard (also on phones from More): a table of the team's numbers
/// for a period, routing efficiency, new clients, catalog distribution, the
/// clients nobody visited in it, and the latest imports.
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
    final clients = ref.watch(workingClientsProvider).value ?? const <Client>[];
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;

    final ids = {for (final u in people) u.id};
    final clientsById = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.id: c};
    // Sales executives are ranked against each other (all of them, so a person
    // keeps their rank when shown alone); KAMs are measured apart.
    final execs = team.where((u) => u.role == UserRole.salesExec).toList();
    final kams = [for (final u in people) if (u.role == UserRole.kam) u];
    final teamReports = buildReports(
      people: execs,
      clients: clients,
      visits: visits,
      tasks: tasks,
      range: _range,
      rules: rules,
      now: now,
    );
    final kamReports = buildReports(
      people: kams,
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
    final newClients = newClientsReport(
      clients: clients,
      people: ids,
      range: _range,
      // Managers looking at everyone also see imports nobody owns yet.
      includeUnowned: _person == null && me.role.isAdmin,
    );
    // Measured against the whole team's benchmark, also when one person is shown.
    final teamRouting = routingReport(
      people: team,
      visits: visits,
      clients: clientsById,
      range: _range,
      timelines: ref.watch(dayTimelinesProvider(_range.months.join(','))).value ?? const {},
    );
    final routing = RoutingReport(
      rows: [for (final r in teamRouting.rows) if (ids.contains(r.user.id)) r],
      pace: teamRouting.pace,
    );
    // First visits vs re-visits need the visited clients' earlier visits.
    final visitedIds = ({
      for (final v in visits)
        if (!v.isCall && v.checkedInAt != null && _range.contains(v.checkedInAt!)) v.clientId,
    }.toList()
      ..sort());
    final before = ref.watch(visitedBeforeProvider((DateFormat('yyyy-MM-dd').format(_range.start), visitedIds.join(','))));
    // Days off don't count in the distance (user 2026-10-31): the person's
    // weekly days off (own schedule, else company hours), holidays and
    // approved full-day leave.
    final workHours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final holidays = ref.watch(holidaysProvider).value ?? const <String>{};
    final leaveDays = <String, Set<String>>{};
    for (final r in ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[]) {
      if (r.isLeave && r.status == LeaveStatus.approved && !r.halfDay && r.from != null && r.to != null) {
        (leaveDays[r.uid] ??= {}).addAll(daysBetween(r.from!, r.to!));
      }
    }
    final teamById = {for (final u in team) u.id: u};
    bool isOffDay(String uid, String day) {
      final date = DateTime.tryParse(day);
      if (date == null) return false;
      final days = (teamById[uid]?.scheduleOr(workHours) ?? workHours).days;
      return !days.contains(date.weekday) || holidays.contains(day) || (leaveDays[uid]?.contains(day) ?? false);
    }

    final ranked = before.value == null
        ? null
        : rankPeople(
            reports: teamReports,
            range: _range,
            visits: visits,
            visitedBefore: before.value!,
            clients: clientsById,
            newClientsFrom: clients,
            routing: teamRouting,
            isOffDay: isOffDay,
          );
    final shown = ranked?.where((p) => ids.contains(p.report.user.id)).toList();
    final lang = Localizations.localeOf(context).languageCode;
    final tags = ref.watch(clientTagsByIdProvider);
    String tagLabel(String id) => id.isEmpty ? l10n.mrNoTag : (tags[id]?.label(lang) ?? id);
    final givenRules = ref.watch(givenItemRulesProvider).value ?? GivenItemRules.defaults;
    final catalogs = catalogReport(
      people: people,
      clients: clients,
      visits: visits,
      range: _range,
      rules: givenRules,
      now: now,
    );
    final rangeLabel = _period == _Period.custom
        ? '${DateFormat.yMMMd(locale).format(_range.start)} – ${DateFormat.yMMMd(locale).format(_range.end)}'
        : DateFormat.yMMMM(locale).format(_range.start);

    ReportPdfContext pdfContext(RankedPerson p, ReportFonts fonts, Uint8List logo) => ReportPdfContext(
          l10n: l10n,
          languageCode: lang,
          periodLabel: rangeLabel,
          teamSize: ranked!.length,
          clients: clientsById,
          tagLabel: tagLabel,
          createdAt: DateTime.now(),
          catalog: catalogReport(
            people: [p.report.user],
            clients: clients,
            visits: visits,
            range: _range,
            rules: givenRules,
            now: now,
          ).rows.single,
          fonts: fonts,
          logo: logo,
        );
    Future<void> download(List<RankedPerson> list, {bool ask = true}) => downloadReportPdfs(
          context,
          people: list,
          contextFor: pdfContext,
          periodLabel: rangeLabel,
          ask: ask,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports), actions: [
        TextButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.downloadPdfs),
          onPressed: shown == null || shown.isEmpty ? null : () => download(shown),
        ),
        const SizedBox(width: 8),
      ]),
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
          if (shown == null || shown.isNotEmpty || kamReports.isEmpty)
            _Section(
              title: l10n.salesExecutivesSection,
              icon: Icons.groups,
              trailing: IconButton(
                tooltip: l10n.scoreInfoTitle,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showScoreInfo(context),
              ),
              child: shown == null
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  : _TeamTable(
                      people: shown,
                      range: _range,
                      onSelect: (id) => setState(() => _person = id),
                      onPdf: (p) => download([p], ask: false),
                    ),
            ),
          if (kamReports.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: l10n.kamSection,
              icon: Icons.supervisor_account,
              child: _KamTable(
                reports: kamReports,
                visits: visits,
                range: _range,
                teams: {for (final k in kamReports) k.user.id: teamOf(k.user, users)},
                onSelect: (id) => setState(() => _person = id),
              ),
            ),
          ],
          if (shown != null && shown.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final types = ClientTypesCard(people: shown, tagLabel: tagLabel);
              final first = FirstVisitsCard(people: shown, clients: clientsById);
              if (c.maxWidth < 900) return Column(children: [types, const SizedBox(height: 12), first]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: types), const SizedBox(width: 12), Expanded(child: first)],
              );
            }),
          ],
          const SizedBox(height: 12),
          RoutingCard(report: routing),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final added = NewClientsCard(report: newClients, users: {for (final u in users) u.id: u});
            final given = CatalogCard(report: catalogs, person: _person);
            if (c.maxWidth < 900) return Column(children: [added, const SizedBox(height: 12), given]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: added),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: given),
              ],
            );
          }),
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

/// Two lines in a cell: the number, and a smaller detail under it.
Widget _twoLines(BuildContext context, Widget main, String? detail) {
  if (detail == null) return main;
  final theme = Theme.of(context);
  return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
    main,
    Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
  ]);
}

/// Whole km with thousands separators.
String _km(double km) => NumberFormat.decimalPattern().format(km.round());

/// A column heading that wraps onto two lines instead of widening the table.
DataColumn _column(String label, double width, void Function(int, bool)? onSort, {bool numeric = true}) => DataColumn(
      label: SizedBox(width: width, child: Text(label, maxLines: 2, softWrap: true, textAlign: numeric ? TextAlign.end : null)),
      numeric: numeric,
      onSort: onSort,
    );

/// Sales executives, ranked, sortable by any column, with a total row.
/// Related numbers share a cell so it fits a screen without scrolling.
class _TeamTable extends StatefulWidget {
  const _TeamTable({required this.people, required this.range, required this.onSelect, required this.onPdf});

  final List<RankedPerson> people;
  final StatsRange range;
  final ValueChanged<String> onSelect;
  final ValueChanged<RankedPerson> onPdf;

  @override
  State<_TeamTable> createState() => _TeamTableState();
}

class _TeamTableState extends State<_TeamTable> {
  int _sortColumn = 0;
  bool _ascending = true;

  static final _sortKeys = <Comparable<Object> Function(RankedPerson)>[
    (p) => p.rank,
    (p) => p.score,
    (p) => p.report.contacts,
    (p) => p.workDays,
    (p) => p.report.clientsVisited,
    (p) => p.newClients,
    (p) => p.distanceKm ?? -1,
    (p) => p.report.coverage ?? -1,
    (p) => p.report.planCompletion ?? -1,
    (p) => p.report.withKam,
    (p) => p.report.flagged,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.people.isEmpty) {
      return Text(l10n.noTrackedStaff, style: theme.textTheme.bodyMedium);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = today.isBefore(widget.range.end) ? today : widget.range.end;
    // Once the period is over the target was reached or not; before, the pace.
    final over = widget.range.end.isBefore(today);
    double expected(AppUser u) =>
        widget.range.start.isAfter(today) ? 0 : targetFor(u.monthlyTarget, widget.range, until: until);

    final rows = [...widget.people]..sort((a, b) {
        final c = _sortKeys[_sortColumn](a).compareTo(_sortKeys[_sortColumn](b));
        return _ascending ? c : -c;
      });
    int sum(int Function(RankedPerson) f) => rows.fold(0, (s, r) => s + f(r));
    final target = rows.fold<double>(0, (s, r) => s + r.report.target);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    void sort(int column, bool ascending) => setState(() {
          _sortColumn = column;
          _ascending = ascending;
        });

    Widget visitsCell(RankedPerson p) {
      final r = p.report;
      final main = Text([visitsAndCallsText(r.visits, r.calls), if (r.target > 0) '${r.target.round()}'].join(' / '));
      if (r.target <= 0) return main;
      final Widget icon;
      if (over) {
        icon = targetVerdict(context, p);
      } else {
        final (paceIcon, color, label) = paceStyle(paceOf(r.contacts, expected(r.user)), l10n);
        icon = Tooltip(message: label, child: Icon(paceIcon, size: 14, color: color));
      }
      return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        main,
        Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 4),
          Text('${(p.targetShare! * 100).round()}%', style: theme.textTheme.bodySmall),
        ]),
      ]);
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _ascending,
            showCheckboxColumn: false,
            columnSpacing: 16,
            horizontalMargin: 8,
            headingRowHeight: 52,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 60,
            columns: [
              _column(l10n.person, 150, sort, numeric: false),
              _column(l10n.mrScore, 48, sort),
              _column(l10n.visitsPlusCalls, 92, sort),
              _column(l10n.mrWorkDays, 56, sort),
              _column(l10n.clientsVisitedColumn, 120, sort),
              _column(l10n.mrNewClients, 52, sort),
              _column(l10n.mrDistance, 76, sort),
              _column(l10n.ownClientsVisited, 104, sort),
              _column(l10n.planCompletion, 84, sort),
              _column(l10n.rideAlongs, 60, sort),
              _column(l10n.flaggedVisits, 56, sort),
              const DataColumn(label: SizedBox.shrink()),
            ],
            rows: [
              for (final p in rows)
                DataRow(
                  onSelectChanged: (_) => widget.onSelect(p.report.user.id),
                  cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      RankBadge(p.rank, size: 24),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 118),
                        child: Text(p.report.user.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ])),
                    DataCell(
                      Text(
                        p.score.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                        ),
                      ),
                      onTap: () => showScoreInfo(context, person: p),
                    ),
                    DataCell(visitsCell(p)),
                    DataCell(Text('${p.workDays}')),
                    DataCell(_twoLines(
                      context,
                      Text('${p.report.clientsVisited}'),
                      l10n.firstAndRevisitedShort(p.firstClients.length, p.revisitedClients.length),
                    )),
                    DataCell(Text('${p.newClients}')),
                    DataCell(_twoLines(
                      context,
                      Text(p.distanceKm == null ? '–' : l10n.mrKm(_km(p.distanceKm!))),
                      p.gpsDays == 0 ? null : l10n.mrGpsDays(p.gpsDays),
                    )),
                    DataCell(_twoLines(
                      context,
                      Text(_ratio(p.report.assignedVisited, p.report.assigned)),
                      p.report.assigned == 0 ? null : l10n.onScheduleShort('${p.report.onSchedule}/${p.report.assigned}'),
                    )),
                    DataCell(Text(_ratio(p.report.tasksDone, p.report.tasksApproved))),
                    DataCell(Text('${p.report.withKam}')),
                    DataCell(Text(
                      '${p.report.flagged}',
                      style: p.report.flagged > 0 ? TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold) : null,
                    )),
                    DataCell(PopupMenuButton<String>(
                      tooltip: l10n.moreActions,
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (action) => switch (action) {
                        'pdf' => widget.onPdf(p),
                        'plan' => context.push('/plan/${p.report.user.id}'),
                        _ => context.go('/history?uid=${p.report.user.id}'),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'pdf', child: ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(l10n.pdfOne))),
                        PopupMenuItem(value: 'plan', child: ListTile(leading: const Icon(Icons.today), title: Text(l10n.openPlan))),
                        PopupMenuItem(value: 'route', child: ListTile(leading: const Icon(Icons.route), title: Text(l10n.routeHistory))),
                      ],
                    )),
                  ],
                ),
              if (rows.length > 1)
                DataRow(cells: [
                  DataCell(Text(l10n.everyone, style: bold)),
                  const DataCell(SizedBox.shrink()),
                  DataCell(Text(
                    [
                      visitsAndCallsText(sum((p) => p.report.visits), sum((p) => p.report.calls)),
                      if (target > 0) '${target.round()}',
                    ].join(' / '),
                    style: bold,
                  )),
                  DataCell(Text('${sum((p) => p.workDays)}', style: bold)),
                  DataCell(_twoLines(
                    context,
                    Text('${sum((p) => p.report.clientsVisited)}', style: bold),
                    l10n.firstAndRevisitedShort(sum((p) => p.firstClients.length), sum((p) => p.revisitedClients.length)),
                  )),
                  DataCell(Text('${sum((p) => p.newClients)}', style: bold)),
                  DataCell(Text(l10n.mrKm(_km(rows.fold(0.0, (s, r) => s + (r.distanceKm ?? 0)))), style: bold)),
                  DataCell(Text(_ratio(sum((p) => p.report.assignedVisited), sum((p) => p.report.assigned)), style: bold)),
                  DataCell(Text(_ratio(sum((p) => p.report.tasksDone), sum((p) => p.report.tasksApproved)), style: bold)),
                  DataCell(Text('${sum((p) => p.report.withKam)}', style: bold)),
                  DataCell(Text('${sum((p) => p.report.flagged)}', style: bold)),
                  const DataCell(SizedBox.shrink()),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// KAMs' own numbers for now: no score or ranking until the user decides
/// how KAMs are measured (2026-10-22).
class _KamTable extends StatelessWidget {
  const _KamTable({
    required this.reports,
    required this.visits,
    required this.range,
    required this.teams,
    required this.onSelect,
  });

  final List<PersonReport> reports;
  final List<Visit> visits;
  final StatsRange range;

  /// KAM id → their sales executives.
  final Map<String, List<AppUser>> teams;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inRange = visits.where((v) => v.checkedInAt != null && range.contains(v.checkedInAt!)).toList();
    DataColumn column(String label, double width, {bool numeric = true}) => _column(label, width, null, numeric: numeric);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.kamSectionNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 16,
              horizontalMargin: 8,
              headingRowHeight: 52,
              columns: [
                column(l10n.person, 150, numeric: false),
                column(l10n.visitsPlusCalls, 92),
                column(l10n.clientsVisitedColumn, 72),
                column(l10n.ownClientsVisited, 104),
                column(l10n.planCompletion, 84),
                column(l10n.kamVisitsWithTeam, 84),
                column(l10n.kamTeamSize, 64),
                column(l10n.kamTeamVisits, 92),
              ],
              rows: [
                for (final r in reports)
                  () {
                    final team = {for (final u in teams[r.user.id] ?? const <AppUser>[]) u.id};
                    final teamContacts = inRange.where((v) => team.contains(v.salesExecId)).toList();
                    return DataRow(
                      onSelectChanged: (_) => onSelect(r.user.id),
                      cells: [
                        DataCell(Text(r.user.name)),
                        DataCell(Text([visitsAndCallsText(r.visits, r.calls), if (r.target > 0) '${r.target.round()}'].join(' / '))),
                        DataCell(Text('${r.clientsVisited}')),
                        DataCell(Text(_ratio(r.assignedVisited, r.assigned))),
                        DataCell(Text(_ratio(r.tasksDone, r.tasksApproved))),
                        DataCell(Text('${inRange.where((v) => v.kamId == r.user.id).length}')),
                        DataCell(Text('${team.length}')),
                        DataCell(Text(visitsAndCallsText(
                          teamContacts.where((v) => !v.isCall).length,
                          teamContacts.where((v) => v.isCall).length,
                        ))),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    ]);
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
