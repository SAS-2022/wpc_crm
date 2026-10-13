import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'stats.dart';

/// Chart colours (reference palette): one series hue, neutral ink for the
/// target, and the fixed status colours (always with icon + label).
const seriesBlue = Color(0xFF2A78D6);
const inkPrimary = Color(0xFF0B0B0B);
const inkSecondary = Color(0xFF52514E);
const statusGood = Color(0xFF0CA30C);
const statusWarning = Color(0xFFFAB219);
const statusCritical = Color(0xFFD03B3B);

(IconData, Color, String) paceStyle(Pace pace, AppLocalizations l10n) => switch (pace) {
      Pace.onTrack => (Icons.check_circle, statusGood, l10n.paceOnTrack),
      Pace.slightlyBehind => (Icons.error, statusWarning, l10n.paceSlightlyBehind),
      Pace.behind => (Icons.warning_rounded, statusCritical, l10n.paceBehind),
    };

/// Status as icon + label; the label text stays in ink.
class PaceLabel extends StatelessWidget {
  const PaceLabel({super.key, required this.pace});

  final Pace pace;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = paceStyle(pace, AppLocalizations.of(context));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ]);
  }
}

/// A KPI: icon, big number, label and an optional line underneath.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.footer});

  final IconData icon;
  final String value;
  final String label;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: theme.textTheme.labelLarge, maxLines: 2)),
            ]),
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (footer != null) ...[const SizedBox(height: 4), footer!],
          ],
        ),
      ),
    );
  }
}

class PersonProgress {
  const PersonProgress({
    required this.id,
    required this.name,
    required this.done,
    required this.target,
    required this.expected,
  });

  final String id;
  final String name;
  final int done;

  /// Target for the selected range (0 = none set).
  final double target;

  /// Target expected by today.
  final double expected;
}

class _Legend extends StatelessWidget {
  const _Legend(this.items);

  final List<(Widget, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final (mark, label) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              mark,
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
        ],
      );
}

/// Horizontal bullet bars: visits completed (blue) with the target as a tick.
/// Tap a row to focus on that person.
class TargetBars extends StatelessWidget {
  const TargetBars({super.key, required this.rows, required this.onSelect});

  final List<PersonProgress> rows;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scale = rows.fold<double>(1, (m, r) => math.max(m, math.max(r.done.toDouble(), r.target)));
    final sorted = [...rows]..sort((a, b) {
        double ratio(PersonProgress r) => r.target > 0 ? r.done / r.target : -1;
        return ratio(b).compareTo(ratio(a));
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Legend([
          (Container(width: 12, height: 12, decoration: BoxDecoration(color: seriesBlue, borderRadius: BorderRadius.circular(3))), l10n.completedVisits),
          (Container(width: 3, height: 14, color: inkPrimary), l10n.target),
        ]),
        const SizedBox(height: 12),
        for (final r in sorted)
          Tooltip(
            message: l10n.barTooltip(r.name, r.done, r.target.round(), r.expected.round()),
            child: InkWell(
              onTap: () => onSelect(r.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final w = c.maxWidth;
                        return SizedBox(
                          height: 24,
                          child: Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [
                              Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Container(
                                width: w * r.done / scale,
                                height: 14,
                                decoration: BoxDecoration(color: seriesBlue, borderRadius: BorderRadius.circular(4)),
                              ),
                              if (r.target > 0)
                                PositionedDirectional(
                                  start: (w * r.target / scale - 1.5).clamp(0, w - 3),
                                  child: Container(width: 3, height: 24, color: inkPrimary),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        r.target > 0 ? '${r.done}/${r.target.round()}' : '${r.done}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (r.target > 0)
                      Icon(paceStyle(paceOf(r.done, r.expected), l10n).$1,
                          size: 18, color: paceStyle(paceOf(r.done, r.expected), l10n).$2)
                    else
                      const SizedBox(width: 18),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One person's visits building up over the range against the target pace.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.range, required this.visitDays, required this.monthlyTarget});

  final StatsRange range;

  /// The day of each visit.
  final List<DateTime> visitDays;
  final int monthlyTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final days = range.dayList;
    final today = DateTime.now();
    final perDay = <DateTime, int>{};
    for (final d in visitDays) {
      final k = DateTime(d.year, d.month, d.day);
      perDay[k] = (perDay[k] ?? 0) + 1;
    }

    final actual = <FlSpot>[];
    final pace = <FlSpot>[];
    var cumulative = 0;
    var targetSoFar = 0.0;
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      cumulative += perDay[d] ?? 0;
      targetSoFar += monthlyTarget / DateTime(d.year, d.month + 1, 0).day;
      if (!d.isAfter(today)) actual.add(FlSpot(i.toDouble(), cumulative.toDouble()));
      pace.add(FlSpot(i.toDouble(), targetSoFar));
    }
    final maxY = math.max(4.0, math.max(cumulative.toDouble(), targetSoFar) * 1.1);
    final step = math.max(1, (days.length / 5).ceil());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Legend([
          (Container(width: 16, height: 3, color: seriesBlue), l10n.completedVisits),
          if (monthlyTarget > 0)
            (const SizedBox(width: 16, child: Text('- -', style: TextStyle(color: inkSecondary, height: 1))), l10n.targetPace),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (days.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(v.toInt().toString(), style: theme.textTheme.bodySmall?.copyWith(color: inkSecondary)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: step.toDouble(),
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(DateFormat.Md(locale).format(days[i]),
                            style: theme.textTheme.bodySmall?.copyWith(color: inkSecondary)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  fitInsideHorizontally: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        s.barIndex == 0
                            ? '${DateFormat.MMMd(locale).format(days[s.x.toInt()])}\n${l10n.completedVisits}: ${s.y.toInt()}'
                            : '${l10n.targetPace}: ${s.y.round()}',
                        TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: actual,
                  color: seriesBlue,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    checkToShowDot: (spot, _) => spot == actual.last,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 4,
                      color: seriesBlue,
                      strokeWidth: 2,
                      strokeColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
                if (monthlyTarget > 0)
                  LineChartBarData(
                    spots: pace,
                    color: inkSecondary,
                    barWidth: 2,
                    dashArray: const [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
