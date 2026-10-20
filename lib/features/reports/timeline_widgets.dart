import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'routing_pace.dart';

Color timeKindColor(TimeKind k) => switch (k) {
      TimeKind.client => const Color(0xFF2E7D32),
      TimeKind.driving => const Color(0xFF1565C0),
      TimeKind.office => const Color(0xFF00838F),
      TimeKind.lunch => const Color(0xFFF9A825),
      TimeKind.stopped => const Color(0xFFD84315),
      TimeKind.noData => const Color(0xFF9E9E9E),
    };

String timeKindLabel(AppLocalizations l10n, TimeKind k) => switch (k) {
      TimeKind.client => l10n.timeAtClients,
      TimeKind.driving => l10n.timeDriving,
      TimeKind.office => l10n.timeOffice,
      TimeKind.lunch => l10n.timeLunch,
      TimeKind.stopped => l10n.timeStopped,
      TimeKind.noData => l10n.timeNoData,
    };

IconData timeKindIcon(TimeKind k) => switch (k) {
      TimeKind.client => Icons.storefront,
      TimeKind.driving => Icons.directions_car,
      TimeKind.office => Icons.apartment,
      TimeKind.lunch => Icons.restaurant,
      TimeKind.stopped => Icons.pause_circle_outline,
      TimeKind.noData => Icons.signal_cellular_off,
    };

/// A stacked bar of where the time went, with a tooltip per part.
class TimeSplitBar extends StatelessWidget {
  const TimeSplitBar({super.key, required this.split, this.height = 14});

  final TimeSplit split;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = split.values.fold(0, (s, n) => s + n);
    if (total == 0) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(children: [
          for (final k in TimeKind.values)
            if ((split[k] ?? 0) > 0)
              Expanded(
                flex: split[k]!,
                child: Tooltip(
                  message: '${timeKindLabel(l10n, k)}: ${formatSplitMinutes(l10n, split[k]!)} (${(split[k]! * 100 / total).round()}%)',
                  child: Container(color: timeKindColor(k)),
                ),
              ),
        ]),
      ),
    );
  }
}

/// Colour key with each part's time and share.
class TimeSplitLegend extends StatelessWidget {
  const TimeSplitLegend({super.key, required this.split});

  final TimeSplit split;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = split.values.fold(0, (s, n) => s + n);
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (final k in TimeKind.values)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 10, color: timeKindColor(k)),
          const SizedBox(width: 4),
          Text(
            total == 0
                ? timeKindLabel(l10n, k)
                : '${timeKindLabel(l10n, k)} ${formatSplitMinutes(l10n, split[k] ?? 0)} · ${((split[k] ?? 0) * 100 / total).round()}%',
            style: style,
          ),
        ]),
    ]);
  }
}

/// "45 min" / "3 h 5 min" in the reader's language.
String formatSplitMinutes(AppLocalizations l10n, int m) =>
    m < 60 ? l10n.durationMinutes(m) : l10n.durationHoursMinutes(m ~/ 60, m % 60);
