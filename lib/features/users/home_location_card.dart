import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/place_buttons.dart';
import '../../l10n/app_localizations.dart';
import 'users_repository.dart';

/// Driver's Home (user request 2026-10-27): asks them to set their home
/// location until it is set (by them or on the user form). It decides their
/// overtime: the drive home after work isn't overtime. Once set, only a
/// manager changes it (rules).
class SetHomeLocationCard extends ConsumerWidget {
  const SetHomeLocationCard({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me.role != UserRole.driver || me.homeLocation != null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_outlined, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.setHomeLocationTitle,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.setHomeLocationText, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: 8),
            PlaceButtons(
              point: null,
              onPicked: (p) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(usersRepositoryProvider).setOwnHomeLocation(me.id, p.latitude, p.longitude);
                  messenger.showSnackBar(SnackBar(content: Text(l10n.homeLocationSaved)));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
