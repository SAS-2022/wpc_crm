import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../clients/clients_repository.dart';
import '../clients/given_items.dart';
import '../clients/given_items_widgets.dart';
import '../home/stats_widgets.dart';
import '../plan/plan_task.dart';
import '../tracking/tracking_log.dart';
import '../visits/visit.dart';
import 'report_sections.dart';
import 'routing_pace.dart';
import 'timeline_widgets.dart';

/// Card frame shared by the report sections.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.title, required this.icon, required this.child, this.trailing});

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
                  Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
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

Widget _stat(BuildContext context, String label, String value, {Color? color}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600)),
      Text(label, style: theme.textTheme.labelMedium),
    ]),
  );
}

/// 1. New clients added in the period.
class NewClientsCard extends StatefulWidget {
  const NewClientsCard({super.key, required this.report, required this.users});

  final NewClientsReport report;
  final Map<String, AppUser> users;

  @override
  State<NewClientsCard> createState() => _NewClientsCardState();
}

class _NewClientsCardState extends State<NewClientsCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final r = widget.report;
    final shown = _all ? r.clients : r.clients.take(10).toList();
    final people = r.addedBy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ReportCard(
      title: l10n.reportNewClients(r.clients.length),
      icon: Icons.person_add_alt,
      child: r.clients.isEmpty
          ? Text(l10n.reportNoNewClients)
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _stat(context, l10n.reportAddedInApp, '${r.manual}'),
                _stat(context, l10n.reportImported, '${r.imported}'),
                for (final MapEntry(key: uid, value: n) in people)
                  _stat(context, widget.users[uid]?.name ?? '?', '$n'),
              ]),
              const SizedBox(height: 8),
              for (final c in shown)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(c.source == 'manual' ? Icons.edit_note : Icons.upload_file),
                  title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (c.city.isNotEmpty) c.city,
                      if (c.source == 'manual' && widget.users[c.createdBy] != null)
                        l10n.reportAddedBy(widget.users[c.createdBy]!.name)
                      else
                        l10n.reportImported,
                      if (c.assignedTo != null && c.assignedTo != c.createdBy) '→ ${widget.users[c.assignedTo]?.name ?? '?'}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(DateFormat.MMMd(locale).format(c.createdAt!)),
                  onTap: () => context.go('/clients/${c.id}'),
                ),
              if (!_all && r.clients.length > shown.length)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(onPressed: () => setState(() => _all = true), child: Text(l10n.showAllCount(r.clients.length))),
                ),
            ]),
    );
  }
}

Color _rateColor(double rate) => rate >= 0.8
    ? statusGood
    : rate >= 0.6
        ? Colors.orange.shade800
        : statusCritical;

/// 2. Routing performance and efficiency: the team benchmark (median of
/// the salespeople's measured averages), where the work days' time went, and
/// each person's days against the benchmark.
class RoutingCard extends StatelessWidget {
  const RoutingCard({super.key, required this.report});

  final RoutingReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final pace = report.pace;
    final rows = report.rows;
    final withDays = rows.where((r) => r.days.isNotEmpty || r.timelines.isNotEmpty).toList()
      ..sort((a, b) => (b.averageRate ?? 0).compareTo(a.averageRate ?? 0));
    final allDays = [for (final r in withDays) ...r.days];
    final lowest = [...allDays]..sort((a, b) => a.efficiency.rate.compareTo(b.efficiency.rate));
    final teamRate = allDays.isEmpty ? null : allDays.fold(0.0, (s, d) => s + d.efficiency.rate) / allDays.length;
    final teamSplit = addSplits(withDays.map((r) => r.split));
    String pct(double r) => '${(r * 100).round()}%';
    String hours(Duration d) => formatLasted(l10n, d);
    String perVisit(double? m) => m == null ? '–' : l10n.minutesShort(m.round());
    String speed(double? k) => k == null ? '–' : l10n.kmPerHour(k.round());

    final benchmark = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          pace.people == 0 ? l10n.reportBenchmarkDefault : l10n.reportBenchmarkTitle(pace.people),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _stat(context, l10n.reportBenchVisit, perVisit(pace.visitMinutes)),
          _stat(context, l10n.reportBenchSpeed, speed(pace.speedKmh)),
          _stat(context, l10n.reportBenchRoad, '×${pace.roadFactor.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 8),
        // The user's own way of thinking about it: 10 clients and the distance between them.
        Text(l10n.reportBenchExample(hours(pace.estimate(10, 30))), style: theme.textTheme.bodyMedium),
        if (pace.measured.length < 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.reportBenchPartly, style: theme.textTheme.bodySmall),
          ),
      ]),
    );

    return ReportCard(
      title: l10n.reportRouting,
      icon: Icons.alt_route,
      child: withDays.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              benchmark,
              const SizedBox(height: 8),
              Text(l10n.reportNoRoutingDays),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              benchmark,
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (teamRate != null) _stat(context, l10n.reportAvgEfficiency, pct(teamRate), color: _rateColor(teamRate)),
                _stat(context, l10n.reportDaysCounted, '${allDays.length}'),
                _stat(
                  context,
                  l10n.reportShortestOrderDays,
                  '${allDays.where((d) => d.efficiency.bestOrder).length}/${allDays.length}',
                ),
                _stat(context, l10n.reportExtraDistance, formatDistance(allDays.fold(0.0, (s, d) => s + d.extraMeters))),
              ]),
              if (teamSplit.values.any((n) => n > 0)) ...[
                const SizedBox(height: 12),
                Text(l10n.reportTimeSplit, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                TimeSplitBar(split: teamSplit, height: 18),
                const SizedBox(height: 6),
                TimeSplitLegend(split: teamSplit),
              ],
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: [
                    DataColumn(label: Text(l10n.person)),
                    DataColumn(label: Text(l10n.efficiency), numeric: true),
                    DataColumn(label: Text(l10n.reportDaysCounted), numeric: true),
                    DataColumn(label: Text(l10n.reportVisitsPerDay), numeric: true),
                    DataColumn(label: Text(l10n.reportBenchVisit), numeric: true),
                    DataColumn(label: Text(l10n.reportBenchSpeed), numeric: true),
                    DataColumn(label: Text(l10n.reportTimeSplit)),
                    DataColumn(label: Text(l10n.reportShortestOrderDays), numeric: true),
                    DataColumn(label: Text(l10n.reportExtraDistance), numeric: true),
                    DataColumn(label: Text(l10n.reportNeededTook), numeric: true),
                  ],
                  rows: [
                    for (final r in withDays)
                      DataRow(cells: [
                        DataCell(Text(r.user.name)),
                        DataCell(r.averageRate == null
                            ? const Text('–')
                            : Text(
                                pct(r.averageRate!),
                                style: TextStyle(color: _rateColor(r.averageRate!), fontWeight: FontWeight.w600),
                              )),
                        DataCell(Text('${r.days.length}')),
                        DataCell(Text(r.visitsPerDay.toStringAsFixed(1))),
                        DataCell(Text(perVisit(r.pace.visitMinutes))),
                        DataCell(Text(speed(r.pace.speedKmh))),
                        DataCell(SizedBox(width: 160, child: TimeSplitBar(split: r.split))),
                        DataCell(Text('${r.bestOrderDays}/${r.days.length}')),
                        DataCell(Text(formatDistance(r.extraMeters))),
                        DataCell(Text('${hours(r.needed)} / ${hours(r.took)}')),
                      ]),
                  ],
                ),
              ),
              if (lowest.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.reportLowestDays, style: theme.textTheme.titleSmall),
              ],
              for (final d in lowest.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _rateColor(d.efficiency.rate).withValues(alpha: 0.15),
                    child: Text(pct(d.efficiency.rate),
                        style: TextStyle(fontSize: 11, color: _rateColor(d.efficiency.rate), fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${d.user.name} · ${DateFormat.MMMEd(locale).format(d.day)}'),
                  subtitle: Text([
                    l10n.visitsCount(d.visits),
                    '${hours(d.efficiency.needed)} / ${hours(d.efficiency.took)}',
                    if (!d.efficiency.bestOrder) '+${formatDistance(d.extraMeters)}',
                    if ((d.timeline?.between?[TimeKind.stopped] ?? 0) > 0)
                      '${timeKindLabel(l10n, TimeKind.stopped)} ${formatSplitMinutes(l10n, d.timeline!.between![TimeKind.stopped]!)}',
                    if (!d.efficiency.measured) l10n.reportNoGpsDay,
                  ].join(' · ')),
                  trailing: const Icon(Icons.route),
                  onTap: () => context.go('/history?uid=${d.user.id}&date=${dayKey(d.day)}'),
                ),
              const SizedBox(height: 4),
              Text(l10n.reportRoutingHelp, style: theme.textTheme.bodySmall),
            ]),
    );
  }
}

/// 3. Catalog distribution.
class CatalogCard extends ConsumerWidget {
  const CatalogCard({super.key, required this.report, this.person});

  final CatalogReport report;

  /// The person picked in the report, for the clients filter.
  final String? person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = report.rows.where((r) => r.total > 0).toList()..sort((a, b) => b.total.compareTo(a.total));
    int sum(GivenItem item) => rows.fold(0, (s, r) => s + (r.byItem[item] ?? 0));
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    // Opens the client list filtered to clients due for [item].
    void openDue(GivenItem item) {
      ref.read(givenDueFilterProvider.notifier)
        ..clear()
        ..toggle(item);
      ref.read(salesFilterProvider.notifier).only(person);
      context.go('/clients');
    }

    return ReportCard(
      title: l10n.reportCatalogs,
      icon: Icons.menu_book,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (rows.isEmpty)
          Text(l10n.reportNoCatalogs)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text(l10n.person)),
                for (final item in GivenItem.values) DataColumn(label: Text(givenItemLabel(l10n, item)), numeric: true),
                DataColumn(label: Text(l10n.reportTotal), numeric: true),
                DataColumn(label: Text(l10n.reportClientsReached), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text(r.user.name)),
                    for (final item in GivenItem.values) DataCell(Text('${r.byItem[item] ?? 0}')),
                    DataCell(Text('${r.total}', style: bold)),
                    DataCell(Text('${r.clients}')),
                  ]),
                if (rows.length > 1)
                  DataRow(cells: [
                    DataCell(Text(l10n.everyone, style: bold)),
                    for (final item in GivenItem.values) DataCell(Text('${sum(item)}', style: bold)),
                    DataCell(Text('${rows.fold(0, (s, r) => s + r.total)}', style: bold)),
                    DataCell(Text('${rows.fold(0, (s, r) => s + r.clients)}', style: bold)),
                  ]),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(l10n.reportCatalogsDue, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in GivenItem.values)
            ActionChip(
              avatar: Icon(givenItemIcon(item), size: 18),
              label: Text(l10n.reportDueNever(
                givenItemLabel(l10n, item),
                report.dueNow[item] ?? 0,
                report.neverGiven[item] ?? 0,
              )),
              onPressed: (report.dueNow[item] ?? 0) == 0 ? null : () => openDue(item),
            ),
        ]),
        const SizedBox(height: 4),
        Text(l10n.reportCatalogsHelp, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}
