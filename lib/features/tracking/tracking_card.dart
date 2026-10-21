import 'package:flutter/material.dart';
import '../../core/location_disclosure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'device_health.dart';
import 'tracking_device.dart';
import 'tracking_status.dart';

/// Home card for field staff: is location sharing on, and what to fix if not.
class TrackingCard extends ConsumerStatefulWidget {
  const TrackingCard({super.key});

  @override
  ConsumerState<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends ConsumerState<TrackingCard> {
  // Settings are usually changed outside the app: re-check on return.
  late final _lifecycle = AppLifecycleListener(onResume: () {
    ref.invalidate(trackingStatusProvider);
    ref.invalidate(phoneHealthProvider);
  });

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, TrackingIssue issue) => switch (issue) {
        TrackingIssue.gpsOff => l10n.issueGpsOff,
        TrackingIssue.locationDenied => l10n.issueLocationDenied,
        TrackingIssue.notAlways => l10n.issueNotAlways,
        TrackingIssue.notifications => l10n.issueNotifications,
        TrackingIssue.battery => l10n.issueBattery,
      };

  Widget _otherPhone(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.phonelink_lock),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.otherPhoneTitle, style: Theme.of(context).textTheme.titleSmall)),
            ]),
            const SizedBox(height: 6),
            Text(l10n.otherPhoneBody),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                onPressed: () async {
                  final me = ref.read(currentUserProvider).value;
                  if (me == null) return;
                  await claimTracking(me.id, await localDeviceId());
                },
                child: Text(l10n.useThisPhone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Another phone signed in to this account shares the location.
    if (ref.watch(thisPhoneTracksProvider).value == false) return _otherPhone(context);
    final status = ref.watch(trackingStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    final ok = status.running && status.issues.isEmpty;
    final health = ref.watch(phoneHealthProvider).value;
    final phoneOk = health == null ||
        (!health.backgroundRestricted && !health.sleeping && !health.needsBrandSetup && health.gap == null);
    // The Android notification already shows sharing is on; only ask for attention.
    if (ok && phoneOk) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    Future<void> refresh() async => ref.invalidate(phoneHealthProvider);

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.share_location : Icons.location_disabled,
                    color: ok ? Colors.green.shade700 : scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.running ? l10n.sharingIncomplete : l10n.sharingOff,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            for (final issue in status.issues)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_label(l10n, issue)),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    // Google Play: say what location is for before Android asks.
                    if ((issue == TrackingIssue.locationDenied || issue == TrackingIssue.notAlways) &&
                        !await showLocationDisclosure(context, LocationUse.tracking)) {
                      return;
                    }
                    await fixTrackingIssue(issue);
                    ref.invalidate(trackingStatusProvider);
                  },
                  child: Text(l10n.fix),
                ),
              ),
            // Today the phone stopped sending for a while (the app was paused).
            if (health?.gap case final gap?)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_toggle_off, color: scheme.error),
                title: Text(l10n.sendGap(time.format(gap.from), time.format(gap.to))),
                trailing: TextButton(
                  onPressed: () async {
                    await dismissSendGap();
                    await refresh();
                  },
                  child: Text(l10n.done),
                ),
              ),
            if (health != null) PhoneHealthTips(health: health),
          ],
        ),
      ),
    );
  }
}

/// What the phone itself may be doing to stop the app in the background:
/// battery "Restricted", Android standby, and the maker's own settings
/// (checklist; Xiaomi Autostart is read when the phone allows). Shown on the
/// tracking card and, for staff who aren't tracked, on the attendance card
/// (automatic check-in needs the app to wake up).
class PhoneHealthTips extends ConsumerWidget {
  const PhoneHealthTips({super.key, required this.health});

  final PhoneHealth health;

  /// Anything to show.
  static bool needed(PhoneHealth? h) => h != null && (h.backgroundRestricted || h.sleeping || h.needsBrandSetup);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (health.backgroundRestricted)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.issueBackgroundRestricted),
            trailing: FilledButton.tonal(onPressed: openAppSettings, child: Text(l10n.fix)),
          ),
        if (health.sleeping)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.issueAppSleeping),
            trailing: FilledButton.tonal(onPressed: openBackgroundSettings, child: Text(l10n.fix)),
          ),
        // The maker's own battery manager: settings the app can't read.
        if (health.needsBrandSetup) ...[
          const Divider(),
          Text(l10n.phoneSetupTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (health.autostart == false)
            Text(l10n.checkInAutostartOff, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Text(makerSetupText(l10n, health.brand)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: openBackgroundSettings,
                child: Text(health.brand == PhoneBrand.xiaomi ? l10n.openAutostart : l10n.openSettings),
              ),
              OutlinedButton(onPressed: openBatterySettings, child: Text(l10n.openBatterySaver)),
              // Read from the phone: confirming wouldn't change it.
              if (health.autostart == null)
                FilledButton.tonal(
                  onPressed: () async {
                    await markBrandSetupDone();
                    ref.invalidate(phoneHealthProvider);
                  },
                  child: Text(l10n.phoneSetupDone),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The maker's checklist text (Autostart, battery saver …).
String makerSetupText(AppLocalizations l10n, PhoneBrand brand) => switch (brand) {
      PhoneBrand.xiaomi => l10n.phoneSetupXiaomi,
      PhoneBrand.samsung => l10n.phoneSetupSamsung,
      PhoneBrand.huawei => l10n.phoneSetupHuawei,
      PhoneBrand.oppo => l10n.phoneSetupOppo,
      PhoneBrand.vivo => l10n.phoneSetupVivo,
      PhoneBrand.oneplus => l10n.phoneSetupOneplus,
      PhoneBrand.other => '',
    };
