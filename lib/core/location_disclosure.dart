import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// What the background location is used for, as told in [showLocationDisclosure].
enum LocationUse {
  /// Sales staff and drivers: live map and route history in work hours.
  tracking,

  /// Everyone else with a work site: automatic check-in / check-out.
  attendance,
}

/// Google Play's "prominent disclosure" (2026-10-21, for the background
/// location declaration): shown in the app before Android's location
/// prompt, saying what location is collected for and that it is used when
/// the app is closed. True = continue to the prompt.
Future<bool> showLocationDisclosure(BuildContext context, LocationUse use) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.share_location),
      title: Text(l10n.locationDisclosureTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (use) {
              LocationUse.tracking => l10n.locationDisclosureTracking,
              LocationUse.attendance => l10n.locationDisclosureAttendance,
            }),
            const SizedBox(height: 12),
            Text(l10n.locationDisclosureNext, style: Theme.of(dialog).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.locationDisclosureNo)),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.locationDisclosureContinue)),
      ],
    ),
  );
  return ok == true;
}
