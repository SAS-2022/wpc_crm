import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'work_hours.dart';

/// GM / sales manager: the days and hours when field staff locations are shared.
class WorkHoursScreen extends ConsumerStatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  ConsumerState<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends ConsumerState<WorkHoursScreen> {
  WorkHours? _edit;
  bool _busy = false;

  /// Saturday first, as in the Saudi work week.
  static const _weekOrder = [
    DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday,
    DateTime.wednesday, DateTime.thursday, DateTime.friday,
  ];

  Future<void> _pickTime({required bool start}) async {
    final h = _edit!;
    final minute = start ? h.startMinute : h.endMinute;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() => _edit = WorkHours(
          days: h.days,
          startMinute: start ? value : h.startMinute,
          endMinute: start ? h.endMinute : value,
        ));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final h = _edit!;
    if (h.endMinute <= h.startMinute) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.endAfterStart)));
      return;
    }
    setState(() => _busy = true);
    try {
      await workHoursRef.set(h.toMap());
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(workHoursProvider).value;
    if (saved == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final h = _edit ??= saved;
    final locale = Localizations.localeOf(context).toString();
    // 2026-10-17 is a Saturday; weekday names from the dates after it.
    String dayName(int weekday) =>
        DateFormat.EEEE(locale).format(DateTime(2026, 10, 17 + _weekOrder.indexOf(weekday)));
    String time(int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workHours)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.workHoursHelp),
          const SizedBox(height: 16),
          Text(l10n.workDays, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _weekOrder)
                FilterChip(
                  label: Text(dayName(d)),
                  selected: h.days.contains(d),
                  onSelected: (on) => setState(() => _edit = WorkHours(
                        days: on ? {...h.days, d} : ({...h.days}..remove(d)),
                        startMinute: h.startMinute,
                        endMinute: h.endMinute,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text('${l10n.startTime}: ${time(h.startMinute)}'),
                  onPressed: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: Text('${l10n.endTime}: ${time(h.endMinute)}'),
                  onPressed: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}
