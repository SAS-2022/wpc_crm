import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/tracking_schedule.dart';
import '../tracking/work_hours.dart';
import '../tracking/work_hours_editor.dart';
import '../users/users_repository.dart';

/// "Company work hours", "All day" or the person's own days and hours.
String trackingScheduleSummary(BuildContext context, TrackingSchedule s, WorkHours company, {required bool driver}) {
  final l10n = AppLocalizations.of(context);
  return switch (s.mode) {
    TrackingMode.allDay => l10n.trackingAllDay,
    TrackingMode.own => WorkHoursEditor.summary(context, s.hours!),
    TrackingMode.standard => driver ? l10n.trackingAllDayDriver : l10n.trackingCompanyHours,
  };
}

/// App settings → Tracking schedules: when each tracked person's location
/// is shared (2026-10-21). Saved in RTDB `settings/trackingSchedules/{uid}`.
class TrackingSchedulesScreen extends ConsumerWidget {
  const TrackingSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider).value;
    final schedules = ref.watch(trackingSchedulesProvider).value ?? const {};
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final people = [
      for (final u in users ?? const <AppUser>[])
        if (u.active && u.role.isLocationTracked) u,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackingSchedules)),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(l10n.trackingSchedulesHelp(WorkHoursEditor.summary(context, company))),
                ),
                if (people.isEmpty) ListTile(title: Text(l10n.noTrackedPeople)),
                for (final u in people)
                  ListTile(
                    leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name.characters.first)),
                    title: Text(u.name),
                    subtitle: Text(
                      '${u.role.label(l10n)} · ${trackingScheduleSummary(context, schedules[u.id] ?? const TrackingSchedule.standard(), company, driver: u.role.isDriver)}',
                    ),
                    trailing: schedules[u.id] == null ? null : const Icon(Icons.edit_calendar_outlined),
                    onTap: () => showTrackingScheduleDialog(
                      context,
                      uid: u.id,
                      name: u.name,
                      driver: u.role.isDriver,
                      current: schedules[u.id],
                      company: company,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Edits the tracking schedule of user [uid]; saves on "Save".
Future<void> showTrackingScheduleDialog(
  BuildContext context, {
  required String uid,
  required String name,
  required bool driver,
  required TrackingSchedule? current,
  required WorkHours company,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ScheduleDialog(
        uid: uid,
        name: name,
        driver: driver,
        current: current ?? const TrackingSchedule.standard(),
        company: company,
      ),
    );

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    required this.uid,
    required this.name,
    required this.driver,
    required this.current,
    required this.company,
  });

  final String uid;
  final String name;
  final bool driver;
  final TrackingSchedule current;
  final WorkHours company;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late TrackingMode _mode = widget.current.mode;
  late WorkHours _hours = widget.current.hours ?? widget.company;
  bool _busy = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_mode == TrackingMode.own && (_hours.days.isEmpty || _hours.endMinute <= _hours.startMinute)) {
      messenger.showSnackBar(SnackBar(content: Text(_hours.days.isEmpty ? l10n.pickWorkDays : l10n.endAfterStart)));
      return;
    }
    final schedule = switch (_mode) {
      TrackingMode.standard => const TrackingSchedule.standard(),
      TrackingMode.allDay => const TrackingSchedule.allDay(),
      TrackingMode.own => TrackingSchedule.own(_hours),
    };
    setState(() => _busy = true);
    try {
      await saving(() => trackingScheduleRef(widget.uid).set(schedule.toMap()));
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = widget.driver;
    return AlertDialog(
      title: Text(l10n.trackingScheduleOf(widget.name)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TrackingMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: TrackingMode.standard, label: Text(l10n.trackingModeStandard)),
                  ButtonSegment(value: TrackingMode.own, label: Text(l10n.trackingModeOwn)),
                  ButtonSegment(value: TrackingMode.allDay, label: Text(l10n.trackingModeAllDay)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              switch (_mode) {
                TrackingMode.standard => Text(driver
                    ? l10n.trackingStandardDriverHelp
                    : l10n.trackingStandardHelp(WorkHoursEditor.summary(context, widget.company))),
                TrackingMode.allDay => Text(l10n.trackingAllDayHelp),
                TrackingMode.own => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.trackingOwnHelp),
                      const SizedBox(height: 12),
                      WorkHoursEditor(value: _hours, onChanged: (v) => setState(() => _hours = v)),
                    ],
                  ),
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
      ],
    );
  }
}
