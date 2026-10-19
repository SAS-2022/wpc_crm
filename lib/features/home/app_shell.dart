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
    // HR, accounting, procurement: Home and More only (branches 0 and 3).
    final backOffice = ref.watch(currentUserProvider).value?.role.isBackOffice ?? false;
    final branches = backOffice ? const [0, 3] : const [0, 1, 2, 3];
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: branches.contains(shell.currentIndex) ? branches.indexOf(shell.currentIndex) : 0,
        // Tapping the current tab again goes back to its first screen.
        onDestinationSelected: (i) =>
            shell.goBranch(branches[i], initialLocation: branches[i] == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: l10n.home),
          if (!backOffice) ...[
            NavigationDestination(icon: const Icon(Icons.store_outlined), selectedIcon: const Icon(Icons.store), label: l10n.clients),
            NavigationDestination(icon: const Icon(Icons.event_note_outlined), selectedIcon: const Icon(Icons.event_note), label: l10n.visits),
          ],
          NavigationDestination(icon: const Icon(Icons.menu), label: l10n.more),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final role = ref.watch(currentUserProvider).value?.role;
    final supervisor = role?.isSupervisor ?? false;
    final backOffice = role?.isBackOffice ?? false;
    final items = [
      (path: '/', icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: l10n.home),
      if (!backOffice) ...[
        (path: '/clients', icon: Icons.store_outlined, selected: Icons.store, label: l10n.clients),
        (path: '/map', icon: Icons.map_outlined, selected: Icons.map, label: l10n.map),
        (path: '/visits', icon: Icons.event_note_outlined, selected: Icons.event_note, label: l10n.visits),
      ],
      if (supervisor) ...[
        (path: '/team-plans', icon: Icons.groups_outlined, selected: Icons.groups, label: l10n.teamPlans),
        (path: '/reports', icon: Icons.table_chart_outlined, selected: Icons.table_chart, label: l10n.reports),
        (path: '/transfers', icon: Icons.swap_horiz_outlined, selected: Icons.swap_horiz, label: l10n.transferredClients),
        (path: '/history', icon: Icons.route_outlined, selected: Icons.route, label: l10n.routeHistory),
        (path: '/live', icon: Icons.my_location_outlined, selected: Icons.my_location, label: l10n.liveTracking),
      ],
      if (role?.canSeeHr ?? false)
        (path: '/attendance', icon: Icons.how_to_reg_outlined, selected: Icons.how_to_reg, label: l10n.attendance),
      // HR entry hidden on the web for now (user request 2026-10-18).
      // if (role?.canSeeHr ?? false) (path: '/hr', icon: Icons.badge_outlined, selected: Icons.badge, label: l10n.hrArea),
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

/// The tabs' navigators side by side, so on phones a sideways swipe moves to
/// the next / previous tab (tapping still works). Swiping only works on a
/// tab's first screen: deeper screens have maps and sliders that need the
/// gesture. Wide screens keep a plain stack (side menu, no swiping).
class BranchPager extends ConsumerStatefulWidget {
  const BranchPager({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  @override
  ConsumerState<BranchPager> createState() => _BranchPagerState();
}

class _BranchPagerState extends ConsumerState<BranchPager> {
  static const _tabRoots = {'/', '/clients', '/visits', '/more'};
  late final _pages = PageController(initialPage: widget.shell.currentIndex);

  /// True while the pager follows a tab tap, so that move isn't taken for a swipe.
  bool _following = false;

  @override
  void didUpdateWidget(BranchPager old) {
    super.didUpdateWidget(old);
    // A tab was tapped (or a link opened another tab): show it without
    // sliding past the tabs in between.
    final index = widget.shell.currentIndex;
    if (_pages.hasClients && _pages.page?.round() != index) {
      _following = true;
      _pages.jumpToPage(index);
      _following = false;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    if (MediaQuery.sizeOf(context).width >= wideLayoutWidth) {
      return IndexedStack(index: shell.currentIndex, children: widget.children);
    }
    // Back-office roles have no Clients / Visits tabs to swipe to.
    final backOffice = ref.watch(currentUserProvider).value?.role.isBackOffice ?? false;
    final atRoot = !backOffice && _tabRoots.contains(shell.shellRouteContext.routerState.uri.path);
    // Switches tab once the swipe has settled, so the gesture isn't cut off
    // halfway by the other tab's screen.
    return NotificationListener<ScrollEndNotification>(
      onNotification: (n) {
        // widget.shell, not the one captured at build: it has the current tab.
        final i = _pages.page?.round();
        if (!_following && n.depth == 0 && i != null && i != widget.shell.currentIndex) widget.shell.goBranch(i);
        return false;
      },
      child: PageView(
        controller: _pages,
        physics: atRoot ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
        children: [for (final child in widget.children) _KeepAlive(child: child)],
      ),
    );
  }
}

/// Keeps a tab's navigator (and its screens' state) while it's off screen.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
