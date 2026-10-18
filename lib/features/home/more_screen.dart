import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';
import 'app_shell.dart';

/// More tab: tools the role can use, language and sign out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    // On wide screens these pages are in the side menu already.
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.more)),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text(me.name.isEmpty ? '?' : me.name.characters.first)),
            title: Text(me.name),
            subtitle: Text('${me.role.label(l10n)} · ${me.email}'),
            trailing: Tooltip(message: l10n.profile, child: const Icon(Icons.chevron_right)),
            onTap: () => context.push('/profile'),
          ),
          const Divider(),
          // My leave hidden for now (user request 2026-10-18).
          // ListTile(
          //   leading: const Icon(Icons.beach_access),
          //   title: Text(l10n.myLeave),
          //   onTap: () => context.push('/leave'),
          // ),
          // Hidden on the web for now (user request 2026-10-18).
          if (me.role.canSeeHr && !wide && !kIsWeb)
            ListTile(
              leading: const Icon(Icons.badge),
              title: Text(l10n.hrArea),
              onTap: () => context.push('/hr'),
            ),
          if (me.role.isTracked)
            ListTile(
              leading: const Icon(Icons.today),
              title: Text(l10n.myPlan),
              onTap: () => context.push('/plan/${me.id}'),
            ),
          if (!wide && me.role.isSales)
            ListTile(
              leading: const Icon(Icons.map),
              title: Text(l10n.map),
              onTap: () => context.go('/map'),
            ),
          if (me.role.isSupervisor && !wide) ...[
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(l10n.teamPlans),
              onTap: () => context.push('/team-plans'),
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(l10n.liveTracking),
              onTap: () => context.push('/live'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(l10n.reports),
              onTap: () => context.push('/reports'),
            ),
            ListTile(
              leading: const Icon(Icons.route),
              title: Text(l10n.routeHistory),
              onTap: () => context.push('/history'),
            ),
          ],
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
              leading: const Icon(Icons.sell_outlined),
              title: Text(l10n.clientTags),
              onTap: () => context.push('/client-tags'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(l10n.locationTypes),
              onTap: () => context.push('/location-types'),
            ),
            ListTile(
              leading: const Icon(Icons.timelapse),
              title: Text(l10n.visitFrequency),
              onTap: () => context.push('/visit-rules'),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.givenItemsSettings),
              onTap: () => context.push('/given-items'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.workHours),
              onTap: () => context.push('/work-hours'),
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
