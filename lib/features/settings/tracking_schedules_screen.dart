import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../../core/search_text.dart';
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

/// One line about [u]'s tracking: tracked live + when, or not tracked live
/// (and whether their GPS is recorded for attendance).
String trackingSummary(BuildContext context, AppUser u, TrackingSchedule? s, WorkHours company) {
  final l10n = AppLocalizations.of(context);
  if (!u.locationTracked) return u.recordsGps ? l10n.notTrackedLiveRecorded : l10n.notTrackedLive;
  return '${l10n.trackedLive} · ${trackingScheduleSummary(context, s ?? const TrackingSchedule.standard(), company, driver: u.role.isDriver)}';
}

enum _Show { all, tracked, notTracked }

/// App settings → Tracking schedules: every active person (2026-11-18, user:
/// any user can be tracked) — whether their location is shared live
/// (`users.liveTracking`, else their role) and when (RTDB
/// `settings/trackingSchedules/{uid}`, 2026-10-21).
class TrackingSchedulesScreen extends ConsumerStatefulWidget {
  const TrackingSchedulesScreen({super.key});

  @override
  ConsumerState<TrackingSchedulesScreen> createState() => _TrackingSchedulesScreenState();
}

class _TrackingSchedulesScreenState extends ConsumerState<TrackingSchedulesScreen> {
  String _query = '';
  _Show _show = _Show.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(usersProvider).value;
    final schedules = ref.watch(trackingSchedulesProvider).value ?? const {};
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final everyone = [
      for (final u in users ?? const <AppUser>[])
        if (u.active && !u.isPendingApproval) u,
    ]..sort((a, b) {
        // Tracked first, then by name.
        final t = (b.locationTracked ? 1 : 0) - (a.locationTracked ? 1 : 0);
        return t != 0 ? t : a.name.compareTo(b.name);
      });
    final searched = [for (final u in everyone) if (searchHas(u.name, _query) || searchHas(u.role.label(l10n), _query)) u];
    final tracked = searched.where((u) => u.locationTracked).length;
    final people = [
      for (final u in searched)
        if (_show == _Show.all || (_show == _Show.tracked) == u.locationTracked) u,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackingSchedules)),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(l10n.trackingSchedulesHelp(WorkHoursEditor.summary(context, company))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.search,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (show, label) in [
                      (_Show.all, '${l10n.statusAll} (${searched.length})'),
                      (_Show.tracked, '${l10n.trackedLive} ($tracked)'),
                      (_Show.notTracked, '${l10n.notTrackedLive} (${searched.length - tracked})'),
                    ])
                      ChoiceChip(label: Text(label), selected: _show == show, onSelected: (_) => setState(() => _show = show)),
                  ]),
                ),
                if (people.isEmpty) ListTile(title: Text(l10n.noTrackedPeople)),
                for (final u in people)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.locationTracked ? null : Theme.of(context).disabledColor.withValues(alpha: 0.2),
                      child: Text(u.name.isEmpty ? '?' : u.name.characters.first),
                    ),
                    title: Text(u.name),
                    subtitle: Text('${u.role.label(l10n)} · ${trackingSummary(context, u, schedules[u.id], company)}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (u.liveTracking != null)
                        Tooltip(message: l10n.trackingSetForPerson, child: const Icon(Icons.person_pin_circle_outlined, size: 20)),
                      if (u.locationTracked && schedules[u.id] != null) const Icon(Icons.edit_calendar_outlined, size: 20),
                      const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => showTrackingScheduleDialog(context, user: u, current: schedules[u.id], company: company),
                  ),
              ],
            ),
    );
  }
}

/// Edits whether [user]'s location is shared live and when; saves on "Save"
/// (users doc + RTDB schedule). Returns the saved `liveTracking` choice
/// (null = as the role) or nothing when cancelled.
Future<({bool? liveTracking})?> showTrackingScheduleDialog(
  BuildContext context, {
  required AppUser user,
  required TrackingSchedule? current,
  required WorkHours company,
}) =>
    showDialog<({bool? liveTracking})>(
      context: context,
      builder: (_) => _ScheduleDialog(user: user, current: current ?? const TrackingSchedule.standard(), company: company),
    );

class _ScheduleDialog extends ConsumerStatefulWidget {
  const _ScheduleDialog({required this.user, required this.current, required this.company});

  final AppUser user;
  final TrackingSchedule current;
  final WorkHours company;

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  late bool _tracked = widget.user.locationTracked;
  late TrackingMode _mode = widget.current.mode;
  late WorkHours _hours = widget.current.hours ?? widget.company;
  bool _busy = false;

  bool get _roleDefault => widget.user.role.isLocationTracked;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_tracked && _mode == TrackingMode.own && (_hours.days.isEmpty || _hours.endMinute <= _hours.startMinute)) {
      messenger.showSnackBar(SnackBar(content: Text(_hours.days.isEmpty ? l10n.pickWorkDays : l10n.endAfterStart)));
      return;
    }
    final schedule = !_tracked
        ? const TrackingSchedule.standard()
        : switch (_mode) {
            TrackingMode.standard => const TrackingSchedule.standard(),
            TrackingMode.allDay => const TrackingSchedule.allDay(),
            TrackingMode.own => TrackingSchedule.own(_hours),
          };
    // Stored only when it differs from the role.
    final live = _tracked == _roleDefault ? null : _tracked;
    setState(() => _busy = true);
    try {
      if (live != widget.user.liveTracking) {
        await ref.read(usersRepositoryProvider).setLiveTracking(widget.user.id, live);
      }
      await saving(() => trackingScheduleRef(widget.user.id).set(schedule.toMap()));
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      navigator.pop((liveTracking: live));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final driver = widget.user.role.isDriver;
    return AlertDialog(
      title: Text(l10n.trackingScheduleOf(widget.user.name)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.trackLiveLocation),
                subtitle: Text(_tracked == _roleDefault
                    ? (_roleDefault ? l10n.trackingRoleDefaultOn : l10n.trackingRoleDefaultOff)
                    : (_tracked ? l10n.trackingTurnedOnForPerson : l10n.trackingTurnedOffForPerson)),
                value: _tracked,
                onChanged: (v) => setState(() => _tracked = v),
              ),
              if (!_tracked)
                Text(
                  widget.user.role.isBackOffice ? l10n.notTrackedRecordedHelp : l10n.notTrackedHelp,
                  style: theme.textTheme.bodySmall,
                ),
              if (_tracked) ...[
                if (!_roleDefault) ...[
                  Text(l10n.trackingOnForPersonHelp, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
      actions: [
        if (widget.user.liveTracking != null)
          TextButton(
            onPressed: _busy ? null : () => setState(() => _tracked = _roleDefault),
            child: Text(l10n.trackingBackToRole),
          ),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
      ],
    );
  }
}
