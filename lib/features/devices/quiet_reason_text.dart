import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../tracking/live_map_screen.dart' show timeAgo;
import 'device_status.dart';

/// The reason a phone sends no location, in words (2026-11-04; replaces a
/// bare "Offline").
String quietReasonText(AppLocalizations l10n, QuietReason r) => switch (r) {
      QuietReason.gpsOff => l10n.quietGpsOff,
      QuietReason.noPermission => l10n.quietNoPermission,
      QuietReason.notRecording => l10n.quietNotRecording,
      QuietReason.noInternet => l10n.quietNoInternet,
      QuietReason.appClosed => l10n.quietAppClosed,
    };

/// "App closed by the phone … · last location 1 h 55 min ago".
String quietLine(BuildContext context, QuietReason r, DateTime? lastPosition, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final reason = quietReasonText(l10n, r);
  return lastPosition == null ? l10n.quietLineNone(reason) : l10n.quietLine(reason, timeAgo(context, lastPosition, now));
}
