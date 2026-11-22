import 'package:flutter/material.dart';

/// Attendance "Hours" bar (2026-11-22, user): a day's counted time split into
/// normal time and overtime (own colour), against the scheduled day.
typedef HoursSplit = ({int normalMin, int overtimeMin, int totalMin, double normalShare, double overtimeShare});

/// [workedMin] counted minutes incl. [overtimeMin]; the bar's full width is
/// the longer of the scheduled day and the time worked.
HoursSplit hoursSplit({required int workedMin, required int overtimeMin, required int scheduledMin}) {
  final worked = workedMin < 0 ? 0 : workedMin;
  final ot = overtimeMin.clamp(0, worked);
  final normal = worked - ot;
  final total = worked > scheduledMin ? worked : scheduledMin;
  if (total == 0) return (normalMin: normal, overtimeMin: ot, totalMin: 0, normalShare: 0, overtimeShare: 0);
  return (normalMin: normal, overtimeMin: ot, totalMin: total, normalShare: normal / total, overtimeShare: ot / total);
}

/// Overtime colours: waiting for approval, approved, not approved.
Color overtimeBarColor({required bool approved, required bool rejected}) => rejected
    ? Colors.grey.shade500
    : approved
        ? Colors.purple.shade400
        : Colors.amber.shade700;

class HoursBar extends StatelessWidget {
  const HoursBar({super.key, required this.split, required this.normalColor, required this.overtimeColor});

  final HoursSplit split;
  final Color normalColor;
  final Color overtimeColor;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final normal = (split.normalShare * 1000).round();
    final ot = (split.overtimeShare * 1000).round();
    final rest = 1000 - normal - ot;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (normal > 0) Expanded(flex: normal, child: ColoredBox(color: normalColor)),
            if (ot > 0) Expanded(flex: ot, child: ColoredBox(color: overtimeColor)),
            if (rest > 0) Expanded(flex: rest, child: ColoredBox(color: bg)),
          ],
        ),
      ),
    );
  }
}
