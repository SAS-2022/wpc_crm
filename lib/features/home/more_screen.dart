import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/page_access.dart';
import '../../core/login_name.dart';
import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';
import 'app_shell.dart';

/// One tile of the More grid.
typedef _Item = ({IconData icon, String label, String path, VoidCallback onTap});

/// More tab: the role's tools as a grid in sections (user request
/// 2026-10-19: stays tidy as items are added), then language and sign out.
/// Pages already in the side menu on wide screens are left out there.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    // On wide screens these pages are in the side menu already.
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final role = me.role;
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    _Item item(IconData icon, String label, String path, {bool go = false}) =>
        (icon: icon, label: label, path: path, onTap: () => go ? context.go(path) : context.push(path));

    final sections = <(String, List<_Item>)>[
      (l10n.moreSectionSales, [
        if (role.isTracked) item(Icons.today, l10n.myPlan, '/plan/${me.id}'),
        if (!wide && role.isSales) item(Icons.map, l10n.map, '/map', go: true),
        if (role.isSupervisor && !wide) ...[
          item(Icons.groups, l10n.teamPlans, '/team-plans'),
          item(Icons.my_location, l10n.liveTracking, '/live'),
          item(Icons.table_chart, l10n.reports, '/reports'),
          item(Icons.swap_horiz, l10n.transferredClients, '/transfers'),
          item(Icons.route, l10n.routeHistory, '/history'),
        ],
      ]),
      (l10n.moreSectionPeople, [
        if (role.seesDrivers) item(Icons.local_shipping_outlined, l10n.driversPage, '/drivers'),
        if (role.managesDrivers) item(Icons.directions_car_outlined, l10n.vehicles, '/vehicles'),
        if (me.seesTeamAttendance && !wide) item(Icons.how_to_reg, l10n.attendance, '/attendance'),
        // On the web again since 2026-10-22 (absences to decide).
        if (role.canSeeHr && !wide) item(Icons.badge, l10n.hrArea, '/hr'),
        if (role.managesUsers) item(Icons.people, l10n.users, '/users'),
      ]),
      (l10n.moreSectionSettings, [
        // Work hours, visit frequency, tags, work sites … are all in App
        // settings (user request 2026-10-21).
        if (role.isAdmin) ...[
          item(Icons.settings_outlined, l10n.appSettings, '/settings'),
          item(Icons.upload_file, l10n.importClients, '/import'),
        ],
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.more)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: ListTile(
              leading: CircleAvatar(child: Text(me.name.isEmpty ? '?' : me.name.characters.first)),
              title: Text(me.name),
              subtitle: Text('${role.label(l10n)} · ${loginNameOf(me.email)}'),
              trailing: Tooltip(message: l10n.profile, child: const Icon(Icons.chevron_right)),
              onTap: () => context.push('/profile'),
            ),
          ),
          for (final (title, all) in sections)
            // Pages turned off for the role (App settings → Page access) are left out.
            if ([for (final i in all) if (access.allowsLocation(me, i.path)) i] case final items when items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(builder: (context, c) {
                  // About 110 px per tile: 3 on a phone, more on wider screens.
                  final columns = (c.maxWidth / 110).floor().clamp(3, 8);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    // Taller tiles when the phone's text is enlarged.
                    childAspectRatio: 1 / MediaQuery.textScalerOf(context).scale(1),
                    children: [for (final i in items) _Tile(item: i)],
                  );
                }),
              ),
            ],
          const SizedBox(height: 16),
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
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(l10n.signOut, style: TextStyle(color: theme.colorScheme.error)),
            onTap: signOut,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(item.icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
