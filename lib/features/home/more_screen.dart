import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';

/// More tab: tools the role can use, language and sign out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.more)),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(me.name.isEmpty ? '?' : me.name.characters.first)),
            title: Text(me.name),
            subtitle: Text('${me.role.label(l10n)} · ${me.email}'),
          ),
          const Divider(),
          if (me.role.isTracked)
            ListTile(
              leading: const Icon(Icons.today),
              title: Text(l10n.myPlan),
              onTap: () => context.push('/plan/${me.id}'),
            ),
          ListTile(
            leading: const Icon(Icons.map),
            title: Text(l10n.map),
            onTap: () => context.go('/map'),
          ),
          if (me.role.isSupervisor)
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(l10n.liveTracking),
              onTap: () => context.push('/live'),
            ),
          if (me.role.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.importClients),
              onTap: () => context.push('/import'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(l10n.users),
              onTap: () => context.push('/users'),
            ),
            ListTile(
              leading: const Icon(Icons.timelapse),
              title: Text(l10n.visitFrequency),
              onTap: () => context.push('/visit-rules'),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'ar', label: Text('ع')),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.signOut, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: signOut,
          ),
        ],
      ),
    );
  }
}
