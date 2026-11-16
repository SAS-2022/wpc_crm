import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../core/time_ago.dart';
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
/// [reportAt]: when the phone sent the report the reason comes from; a
/// setting read from an old report (GPS, permission, internet) says so —
/// the phone may have been fixed since (2026-11-15).
String quietLine(BuildContext context, QuietReason r, DateTime? lastPosition, DateTime now, {DateTime? reportAt}) {
  final l10n = AppLocalizations.of(context);
  var reason = quietReasonText(l10n, r);
  final fromSetting = r == QuietReason.gpsOff || r == QuietReason.noPermission || r == QuietReason.noInternet;
  if (fromSetting && reportAt != null && now.difference(reportAt) >= stoppedAfter) {
    reason = l10n.quietAsOf(reason, timeAgo(context, reportAt, now));
  }
  return lastPosition == null ? l10n.quietLineNone(reason) : l10n.quietLine(reason, timeAgo(context, lastPosition, now));
}
