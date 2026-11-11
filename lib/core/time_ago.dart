import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// "Just now", "5 min ago", "2 h ago", else the date and time.
String timeAgo(BuildContext context, DateTime? t, DateTime now) {
  final l10n = AppLocalizations.of(context);
  if (t == null) return l10n.never;
  final m = now.difference(t).inMinutes;
  if (m < 1) return l10n.justNow;
  if (m < 60) return l10n.minutesAgo(m);
  if (m < 24 * 60) return l10n.hoursAgo(m ~/ 60);
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(t);
}
