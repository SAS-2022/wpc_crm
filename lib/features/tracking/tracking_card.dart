import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import 'tracking_status.dart';

/// Home card for field staff: is location sharing on, and what to fix if not.
class TrackingCard extends ConsumerStatefulWidget {
  const TrackingCard({super.key});

  @override
  ConsumerState<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends ConsumerState<TrackingCard> {
  // Settings are usually changed outside the app: re-check on return.
  late final _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(trackingStatusProvider));

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(trackingStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    final ok = status.running && status.issues.isEmpty;
    // The Android notification already shows sharing is on; only ask for attention.
    if (ok) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: ok ? Colors.green.shade50 : scheme.errorContainer,
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
                    ok ? l10n.sharingOn : (status.running ? l10n.sharingIncomplete : l10n.sharingOff),
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
                    await fixTrackingIssue(issue);
                    ref.invalidate(trackingStatusProvider);
                  },
                  child: Text(l10n.fix),
                ),
              ),
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              const SizedBox(height: 4),
              Text(l10n.xiaomiHint, style: Theme.of(context).textTheme.bodySmall),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: openAppSettings, child: Text(l10n.appSettings)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
