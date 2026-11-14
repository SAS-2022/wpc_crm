import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';

/// On the user form of a self-registered account (2026-11-12): when it
/// registered and from which phone / browser and IP address.
class RegisteredFromCard extends StatelessWidget {
  const RegisteredFromCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final src = user.registeredFrom;
    final at = user.registeredAt;
    final lines = <String>[
      if (at != null) DateFormat.yMMMd(locale).add_jm().format(at),
      if (src == null)
        l10n.registeredFromUnknown
      else ...[
        if (src.platform == 'web') l10n.registeredFromWeb,
        if (src.device.isNotEmpty) src.device,
        if (src.app != null) l10n.registeredFromApp(src.app!),
        if (src.ip != null) l10n.registeredFromIp(src.ip!),
        ?src.language,
      ],
    ];
    final icon = switch (src?.platform) {
      'web' => Icons.public,
      'ios' => Icons.phone_iphone,
      'android' => Icons.phone_android,
      _ => Icons.devices_other,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(l10n.registeredFrom),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines) Text(l),
            if (src?.emulator ?? false)
              Text(l10n.registeredFromEmulator, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
            if (src?.userAgent case final ua? when src?.platform == 'web')
              Text(ua, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
