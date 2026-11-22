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
    // Fixed widths from the row's width (2026-11-22: the Expanded version
    // drew nothing in the web release build).
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 200.0;
        final normal = w * split.normalShare.clamp(0.0, 1.0);
        final ot = w * split.overtimeShare.clamp(0.0, 1.0 - split.normalShare.clamp(0.0, 1.0));
        return Container(
          width: w,
          height: 8,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          clipBehavior: Clip.antiAlias,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (normal > 0) Container(width: normal, height: 8, color: normalColor),
              if (ot > 0) Container(width: ot, height: 8, color: overtimeColor),
            ],
          ),
        );
      },
    );
  }
}
