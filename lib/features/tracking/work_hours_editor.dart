import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'work_hours.dart';

/// Work days (chips) and start / end time buttons. Used for the company work
/// hours (More → Work hours) and a person's own schedule (user form).
class WorkHoursEditor extends StatelessWidget {
  const WorkHoursEditor({super.key, required this.value, required this.onChanged});

  final WorkHours value;
  final ValueChanged<WorkHours> onChanged;

  /// Saturday first, as in the Saudi work week.
  static const weekOrder = [
    DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday,
    DateTime.wednesday, DateTime.thursday, DateTime.friday,
  ];

  /// "Sat–Thu 8:00 AM – 5:00 PM" style summary.
  static String summary(BuildContext context, WorkHours h) {
    final locale = Localizations.localeOf(context).toString();
    String time(int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    final days = [for (final d in weekOrder) if (h.days.contains(d)) _dayName(locale, d, short: true)].join(', ');
    return '$days · ${time(h.startMinute)} – ${time(h.endMinute)}';
  }

  // 2026-10-17 is a Saturday; weekday names from the dates after it.
  static String _dayName(String locale, int weekday, {bool short = false}) {
    final date = DateTime(2026, 10, 17 + weekOrder.indexOf(weekday));
    return (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(date);
  }

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final minute = start ? value.startMinute : value.endMinute;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    onChanged(WorkHours(
      days: value.days,
      startMinute: start ? m : value.startMinute,
      endMinute: start ? value.endMinute : m,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    String time(int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.workDays, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in weekOrder)
              FilterChip(
                label: Text(_dayName(locale, d)),
                selected: value.days.contains(d),
                onSelected: (on) => onChanged(WorkHours(
                  days: on ? {...value.days, d} : ({...value.days}..remove(d)),
                  startMinute: value.startMinute,
                  endMinute: value.endMinute,
                )),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: Text('${l10n.startTime}: ${time(value.startMinute)}'),
                onPressed: () => _pickTime(context, start: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text('${l10n.endTime}: ${time(value.endMinute)}'),
                onPressed: () => _pickTime(context, start: false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
