import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../plan/plan_task.dart';
import '../visits/visit.dart';
import 'stats_widgets.dart';

/// One coloured slice / bar segment with its count.
typedef _Part = ({String label, Color color, int count});

/// Plan items of the period: done, to do, missed (past and not done) and
/// waiting for approval. A donut for the total, and a stacked bar per person
/// when the dashboard shows more than one. Tap a person to focus on them.
class PlanProgressCard extends StatelessWidget {
  const PlanProgressCard({
    super.key,
    required this.people,
    required this.tasks,
    required this.today,
    required this.onSelect,
  });

  final List<AppUser> people;
  final List<PlanTask> tasks;
  final DateTime today;
  final ValueChanged<String> onSelect;

  List<_Part> _parts(AppLocalizations l10n, Iterable<PlanTask> list) {
    var done = 0, toDo = 0, missed = 0, waiting = 0;
    for (final t in list) {
      if (t.approval == TaskApproval.rejected) continue;
      if (t.approval == TaskApproval.pending) {
        waiting++;
      } else if (t.done) {
        done++;
      } else if (DateTime.parse(t.date).isBefore(today)) {
        missed++;
      } else {
        toDo++;
      }
    }
    return [
      (label: l10n.done, color: statusGood, count: done),
      (label: l10n.toDo, color: seriesBlue, count: toDo),
      (label: l10n.missed, color: statusCritical, count: missed),
      (label: l10n.waitingApproval, color: statusWarning, count: waiting),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = _parts(l10n, tasks);
    final total = parts.fold(0, (s, p) => s + p.count);
    return _ChartCard(
      title: l10n.planProgress,
      icon: Icons.checklist,
      child: total == 0
          ? _Empty(l10n.noPlanItems)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Donut(parts: parts, center: '${parts.first.count}', caption: l10n.ofTotal(total)),
                if (people.length > 1) ...[
                  const Divider(height: 28),
                  for (final u in people)
                    if (_parts(l10n, tasks.where((t) => t.ownerId == u.id)) case final p
                        when p.any((x) => x.count > 0))
                      _StackedRow(name: u.name, parts: p, trailing: '${p.first.count}/${p.fold(0, (s, x) => s + x.count)}', onTap: () => onSelect(u.id)),
                ],
              ],
            ),
    );
  }
}

/// For each salesperson: how many of their clients were visited in the period
/// (by anyone) and how many are still waiting for a visit.
class ClientVisitsCard extends StatelessWidget {
  const ClientVisitsCard({
    super.key,
    required this.people,
    required this.clients,
    required this.visits,
    required this.onSelect,
  });

  final List<AppUser> people;

  /// All clients, of any assignment; filtered per person here.
  final List<Client> clients;

  /// Visits of the period, by any visitor.
  final List<Visit> visits;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visited = {for (final v in visits) v.clientId};
    final pendingColor = theme.colorScheme.outlineVariant;

    final rows = [
      for (final u in people)
        if (clients.where((c) => c.assignedTo == u.id).toList() case final mine when mine.isNotEmpty)
          (user: u, total: mine.length, visited: mine.where((c) => visited.contains(c.id)).length),
    ]..sort((a, b) => (b.visited / b.total).compareTo(a.visited / a.total));
    final total = rows.fold(0, (s, r) => s + r.total);
    final done = rows.fold(0, (s, r) => s + r.visited);
    List<_Part> parts(int v, int t) => [
          (label: l10n.visitedLabel, color: statusGood, count: v),
          (label: l10n.notVisitedYet, color: pendingColor, count: t - v),
        ];

    return _ChartCard(
      title: l10n.clientVisitsCard,
      icon: Icons.store,
      child: total == 0
          ? _Empty(l10n.noAssignedClients)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Donut(parts: parts(done, total), center: '${(100 * done / total).round()}%', caption: l10n.visitedLabel),
                const SizedBox(height: 8),
                Text(
                  l10n.visitedOfClients(done, total, total - done),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (rows.length > 1) ...[
                  const Divider(height: 28),
                  for (final r in rows)
                    _StackedRow(
                      name: r.user.name,
                      parts: parts(r.visited, r.total),
                      trailing: '${r.visited}/${r.total}',
                      onTap: () => onSelect(r.user.id),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

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
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// Donut with a big number in the middle and a legend with counts beside it.
class _Donut extends StatelessWidget {
  const _Donut({required this.parts, required this.center, required this.caption});

  final List<_Part> parts;
  final String center;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = parts.where((p) => p.count > 0).toList();
    return Row(
      children: [
        SizedBox.square(
          dimension: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                centerSpaceRadius: 46,
                sectionsSpace: visible.length > 1 ? 2 : 0,
                startDegreeOffset: -90,
                sections: [
                  for (final p in visible)
                    PieChartSectionData(value: p.count.toDouble(), color: p.color, radius: 20, showTitle: false),
                ],
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(caption, style: theme.textTheme.bodySmall),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in parts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.label, style: theme.textTheme.bodyMedium)),
                    Text('${p.count}', style: theme.textTheme.labelLarge),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A person's name, a bar split into coloured parts, and a count.
class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.name, required this.parts, required this.trailing, required this.onTap});

  final String name;
  final List<_Part> parts;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = parts.where((p) => p.count > 0).toList();
    return Tooltip(
      message: [name, for (final p in visible) '${p.label}: ${p.count}'].join('\n'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 96,
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 14,
                  child: Row(children: [
                    for (final (i, p) in visible.indexed)
                      Expanded(
                        flex: p.count,
                        child: Container(
                          color: p.color,
                          margin: EdgeInsetsDirectional.only(end: i == visible.length - 1 ? 0 : 2),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(trailing, textAlign: TextAlign.end, style: theme.textTheme.labelLarge),
            ),
          ]),
        ),
      ),
    );
  }
}
