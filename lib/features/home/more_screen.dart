import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';
import 'app_shell.dart';

/// One tile of the More grid.
typedef _Item = ({IconData icon, String label, VoidCallback onTap});

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
    _Item item(IconData icon, String label, String path, {bool go = false}) =>
        (icon: icon, label: label, onTap: () => go ? context.go(path) : context.push(path));

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
        if (role.managesDrivers) item(Icons.local_shipping_outlined, l10n.driversPage, '/drivers'),
        if (role.canSeeHr && !wide) item(Icons.how_to_reg, l10n.attendance, '/attendance'),
        // HR area hidden on the web for now (user request 2026-10-18).
        if (role.canSeeHr && !wide && !kIsWeb) item(Icons.badge, l10n.hrArea, '/hr'),
        if (role.isAdmin) ...[
          item(Icons.people, l10n.users, '/users'),
          item(Icons.apartment, l10n.workSites, '/work-sites'),
          item(Icons.business, l10n.companies, '/companies'),
          item(Icons.work_outline, l10n.positions, '/positions'),
        ],
      ]),
      (l10n.moreSectionSettings, [
        if (role.isAdmin) ...[
          item(Icons.upload_file, l10n.importClients, '/import'),
          item(Icons.sell_outlined, l10n.clientTags, '/client-tags'),
          item(Icons.place_outlined, l10n.locationTypes, '/location-types'),
          item(Icons.timelapse, l10n.visitFrequency, '/visit-rules'),
          item(Icons.menu_book_outlined, l10n.givenItemsSettings, '/given-items'),
          item(Icons.schedule, l10n.workHours, '/work-hours'),
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
              subtitle: Text('${role.label(l10n)} · ${me.email}'),
              trailing: Tooltip(message: l10n.profile, child: const Icon(Icons.chevron_right)),
              onTap: () => context.push('/profile'),
            ),
          ),
          for (final (title, items) in sections)
            if (items.isNotEmpty) ...[
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
                    childAspectRatio: 1,
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
