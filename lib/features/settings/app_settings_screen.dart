import '../hr/hr_people.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/tracking_schedule.dart';
import '../tracking/work_hours.dart';
import '../tracking/work_hours_editor.dart';
import 'app_settings.dart';

/// GM / sales manager: every setting of the app in one place (user request
/// 2026-10-21) — the settings pages that were in More, plus the limits of
/// [AppSettings] edited here.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final company = ref.watch(workHoursProvider).value;
    final schedules = ref.watch(trackingSchedulesProvider).value ?? const {};

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget page(IconData icon, String title, String path, {String? subtitle}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );
    Widget number(IconData icon, AppSetting s) => _NumberTile(icon: icon, setting: s, value: settings[s]);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header(l10n.settingsSectionAccess),
          page(Icons.lock_person_outlined, l10n.pageAccess, '/settings/page-access', subtitle: l10n.pageAccessSubtitle),
          header(l10n.settingsSectionTracking),
          page(Icons.schedule, l10n.workHours, '/work-hours',
              subtitle: company == null ? null : WorkHoursEditor.summary(context, company)),
          page(Icons.edit_calendar_outlined, l10n.trackingSchedules, '/settings/tracking-schedules',
              subtitle: l10n.trackingSchedulesCount(schedules.length)),
          number(Icons.timer_outlined, AppSetting.trackingIntervalSec),
          number(Icons.portable_wifi_off, AppSetting.offlineAlertMin),
          header(l10n.settingsSectionClients),
          page(Icons.timelapse, l10n.visitFrequency, '/visit-rules'),
          page(Icons.menu_book_outlined, l10n.givenItemsSettings, '/given-items'),
          page(Icons.sell_outlined, l10n.clientTags, '/client-tags'),
          page(Icons.place_outlined, l10n.locationTypes, '/location-types'),
          number(Icons.social_distance, AppSetting.visitRadiusM),
          number(Icons.event_repeat, AppSetting.givenDueSoonDays),
          header(l10n.settingsSectionPeople),
          page(Icons.apartment, l10n.workSites, '/work-sites'),
          page(Icons.business, l10n.companies, '/companies'),
          number(Icons.more_time, AppSetting.lateGraceMin),
          number(Icons.directions_walk, AppSetting.awayGraceMin),
          number(Icons.home_outlined, AppSetting.driveHomeGraceMin),
          header(l10n.settingsSectionHr),
          const AnnualCarryOverTile(),
          page(Icons.account_tree_outlined, l10n.departments, '/departments'),
          header(l10n.vehicles),
          number(Icons.directions_car_outlined, AppSetting.vehicleRenewalDays),
          number(Icons.oil_barrel_outlined, AppSetting.oilDueSoonKm),
        ],
      ),
    );
  }
}

String settingTitle(AppLocalizations l10n, AppSetting s) => switch (s) {
      AppSetting.trackingIntervalSec => l10n.settingTrackingInterval,
      AppSetting.offlineAlertMin => l10n.settingOfflineAlert,
      AppSetting.visitRadiusM => l10n.settingVisitRadius,
      AppSetting.lateGraceMin => l10n.settingLateGrace,
      AppSetting.awayGraceMin => l10n.settingAwayGrace,
      AppSetting.driveHomeGraceMin => l10n.settingDriveHomeGrace,
      AppSetting.givenDueSoonDays => l10n.settingGivenDueSoon,
      AppSetting.vehicleRenewalDays => l10n.settingVehicleRenewal,
      AppSetting.oilDueSoonKm => l10n.settingOilDueSoon,
    };

String settingHelp(AppLocalizations l10n, AppSetting s) => switch (s) {
      AppSetting.trackingIntervalSec => l10n.settingTrackingIntervalHelp,
      AppSetting.offlineAlertMin => l10n.settingOfflineAlertHelp,
      AppSetting.visitRadiusM => l10n.settingVisitRadiusHelp,
      AppSetting.lateGraceMin => l10n.settingLateGraceHelp,
      AppSetting.awayGraceMin => l10n.settingAwayGraceHelp,
      AppSetting.driveHomeGraceMin => l10n.settingDriveHomeGraceHelp,
      AppSetting.givenDueSoonDays => l10n.settingGivenDueSoonHelp,
      AppSetting.vehicleRenewalDays => l10n.settingVehicleRenewalHelp,
      AppSetting.oilDueSoonKm => l10n.settingOilDueSoonHelp,
    };

/// "30 seconds", "300 m" …
String settingValue(AppLocalizations l10n, AppSetting s, int v) => switch (s) {
      AppSetting.trackingIntervalSec => l10n.valueSeconds(v),
      AppSetting.offlineAlertMin || AppSetting.lateGraceMin || AppSetting.awayGraceMin || AppSetting.driveHomeGraceMin =>
        l10n.valueMinutes(v),
      AppSetting.visitRadiusM => l10n.valueMeters(v),
      AppSetting.givenDueSoonDays || AppSetting.vehicleRenewalDays => l10n.valueDays(v),
      AppSetting.oilDueSoonKm => l10n.kmValue('$v'),
    };

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.icon, required this.setting, required this.value});

  final IconData icon;
  final AppSetting setting;
  final int value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(settingTitle(l10n, setting)),
      subtitle: Text(settingHelp(l10n, setting)),
      trailing: Text(
        settingValue(l10n, setting, value),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _NumberDialog(setting: setting, value: value),
      ),
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({required this.setting, required this.value});

  final AppSetting setting;
  final int value;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(text: '${widget.value}');
  String? _error;
  bool _busy = false;

  AppSetting get _s => widget.setting;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [value] null = back to the default.
  Future<void> _save(int? value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (value != null && (value < _s.min || value > _s.max)) {
      setState(() => _error = l10n.settingRange(settingValue(l10n, _s, _s.min), settingValue(l10n, _s, _s.max)));
      return;
    }
    setState(() => _busy = true);
    try {
      await saving(() => appSettingsRef.child(_s.name).set(value));
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
    return AlertDialog(
      title: Text(settingTitle(l10n, _s)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(settingHelp(l10n, _s)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
                helperText: l10n.settingDefault(settingValue(l10n, _s, _s.defaultValue)),
              ),
              onSubmitted: (v) => _save(int.tryParse(v) ?? -1),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => _save(null), child: Text(l10n.resetToDefault)),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _busy ? null : () => _save(int.tryParse(_controller.text) ?? -1),
          child: BusyLabel(busy: _busy, child: Text(l10n.save)),
        ),
      ],
    );
  }
}
