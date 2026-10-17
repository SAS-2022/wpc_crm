import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'visit.dart';

/// Calls are drawn in this colour everywhere (lists, chips, target bars), so
/// they never look like visits. Purple: apart from the visit blue and the
/// green / yellow / red status colours.
const callColor = Color(0xFF8E44C9);

/// "Call" chip, with "From the app · 4 min" when it was dialled from the app.
class CallChip extends StatelessWidget {
  const CallChip({super.key, required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = [
      l10n.call,
      if (visit.callFromApp) l10n.callFromApp,
      if (visit.callFromApp && visit.callSeconds != null) formatCallDuration(visit.callSeconds!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: callColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(visit.callFromApp ? Icons.phone_forwarded : Icons.call, size: 14, color: callColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: callColor, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }
}
