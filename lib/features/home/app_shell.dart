import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// Below this width: bottom tabs (phones). From it: a side menu (web,
/// tablets) with the dashboard pages as their own entries.
const wideLayoutWidth = 900.0;

/// Bottom tabs: Home · Clients · Visits · More. Each tab keeps its own
/// navigation stack. On wide screens a side menu replaces the tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell, required this.location});

  final StatefulNavigationShell shell;

  /// Current path, to highlight the side menu entry.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (MediaQuery.sizeOf(context).width >= wideLayoutWidth) return _wide(context, ref, l10n);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again goes back to its first screen.
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.store_outlined), selectedIcon: const Icon(Icons.store), label: l10n.clients),
          NavigationDestination(icon: const Icon(Icons.event_note_outlined), selectedIcon: const Icon(Icons.event_note), label: l10n.visits),
          NavigationDestination(icon: const Icon(Icons.menu), label: l10n.more),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final role = ref.watch(currentUserProvider).value?.role;
    final supervisor = role?.isSupervisor ?? false;
    final items = [
      (path: '/', icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: l10n.home),
      (path: '/clients', icon: Icons.store_outlined, selected: Icons.store, label: l10n.clients),
      (path: '/map', icon: Icons.map_outlined, selected: Icons.map, label: l10n.map),
      (path: '/visits', icon: Icons.event_note_outlined, selected: Icons.event_note, label: l10n.visits),
      if (supervisor) ...[
        (path: '/reports', icon: Icons.table_chart_outlined, selected: Icons.table_chart, label: l10n.reports),
        (path: '/history', icon: Icons.route_outlined, selected: Icons.route, label: l10n.routeHistory),
        (path: '/live', icon: Icons.my_location_outlined, selected: Icons.my_location, label: l10n.liveTracking),
      ],
      (path: '/more', icon: Icons.menu, selected: Icons.menu_open, label: l10n.more),
    ];
    // The entry whose path is the longest prefix of the location; Home also
    // holds the plan and notification pages.
    var index = 0;
    for (final (i, item) in items.indexed) {
      final matches = item.path == '/'
          ? location == '/' || location.startsWith('/plan') || location.startsWith('/notifications')
          : location == item.path || location.startsWith('${item.path}/');
      if (matches) index = i;
    }
    final extended = MediaQuery.sizeOf(context).width >= 1200;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            selectedIndex: index,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.asset('assets/images/Regular.png', width: extended ? 140 : 56),
            ),
            onDestinationSelected: (i) => context.go(items[i].path),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selected),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
