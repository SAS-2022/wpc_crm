import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../hr/leave_rules.dart' show myLeaveEnabled;
import '../settings/page_access.dart';
import '../users/users_repository.dart';
import 'app_shell.dart' show visibleBranches;
import 'bottom_tabs.dart';

/// A page that can be a bottom tab.
typedef TabOption = ({String path, IconData icon, IconData selected, String label});

/// Every page the signed-in person may put in the bottom bar, in the
/// default order (same conditions as the web side menu and More).
List<TabOption> bottomTabOptions(WidgetRef ref, AppLocalizations l10n) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const [];
  final role = me.can;
  final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
  final backOffice = role.isBackOffice;
  final supervisor = role.isSupervisor;
  final List<TabOption> all = [
    (path: '/', icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: l10n.home),
    if (!backOffice) ...[
      (path: '/clients', icon: Icons.store_outlined, selected: Icons.store, label: l10n.clients),
      (path: '/map', icon: Icons.map_outlined, selected: Icons.map, label: l10n.clientMap),
      (path: '/visits', icon: Icons.event_note_outlined, selected: Icons.event_note, label: l10n.visits),
    ],
    if (role.isTracked) (path: '/plan/${me.id}', icon: Icons.today_outlined, selected: Icons.today, label: l10n.myPlan),
    if (supervisor) ...[
      (path: '/team-plans', icon: Icons.groups_outlined, selected: Icons.groups, label: l10n.teamPlans),
      (path: '/reports', icon: Icons.table_chart_outlined, selected: Icons.table_chart, label: l10n.reports),
      (path: '/transfers', icon: Icons.swap_horiz_outlined, selected: Icons.swap_horiz, label: l10n.transferredClients),
      (path: '/catalogs', icon: Icons.style_outlined, selected: Icons.style, label: l10n.catalogsPage),
      (path: '/history', icon: Icons.route_outlined, selected: Icons.route, label: l10n.routeHistory),
      (path: '/live', icon: Icons.my_location_outlined, selected: Icons.my_location, label: l10n.liveTracking),
    ],
    if (me.seesEmployeesMap)
      (
        path: '/attendance/map',
        icon: Icons.person_pin_circle_outlined,
        selected: Icons.person_pin_circle,
        label: l10n.employeesMap,
      ),
    if (me.seesTeamAttendance)
      (path: '/attendance', icon: Icons.how_to_reg_outlined, selected: Icons.how_to_reg, label: l10n.attendance),
    if (myLeaveEnabled)
      (path: '/leave', icon: Icons.beach_access_outlined, selected: Icons.beach_access, label: l10n.myLeave),
    if (role.canSeeHr) (path: '/hr', icon: Icons.badge_outlined, selected: Icons.badge, label: l10n.hrArea),
    if (role.seesCompanyDocs)
      (path: '/documents', icon: Icons.folder_copy_outlined, selected: Icons.folder_copy, label: l10n.companyDocs),
    if (role.seesPhoneStatus)
      (
        path: '/phone-status',
        icon: Icons.phonelink_setup_outlined,
        selected: Icons.phonelink_setup,
        label: l10n.phoneStatus,
      ),
    if (role.managesVehicles)
      (path: '/vehicles', icon: Icons.directions_car_outlined, selected: Icons.directions_car, label: l10n.vehicles),
    if (role.managesUsers) (path: '/users', icon: Icons.people_outline, selected: Icons.people, label: l10n.users),
    (
      path: '/notifications',
      icon: Icons.notifications_outlined,
      selected: Icons.notifications,
      label: l10n.notifications,
    ),
  ];
  return [
    for (final o in all)
      if (access.allowsLocation(me, o.path)) o,
  ];
}

/// The default tabs (More not included): Home, Clients, Visits as allowed.
List<String> defaultBottomTabs(WidgetRef ref) => [
  for (final b in visibleBranches(ref))
    if (b != 3) branchRoots.entries.firstWhere((e) => e.value == b).key,
];

/// The person's bottom tabs now (More not included).
List<TabOption> myBottomTabs(WidgetRef ref, AppLocalizations l10n) {
  final options = bottomTabOptions(ref, l10n);
  final byPath = {for (final o in options) o.path: o};
  final paths = resolveBottomTabs(
    saved: ref.watch(currentUserProvider).value?.bottomTabs,
    available: byPath.keys.toList(),
    defaults: [
      for (final p in defaultBottomTabs(ref))
        if (byPath.containsKey(p)) p,
    ],
  );
  return [for (final p in paths) ?byPath[p]];
}

/// More → Bottom tabs (2026-11-08, user request): each person picks up to
/// four tabs and their order; More stays the last tab.
class BottomTabsScreen extends ConsumerStatefulWidget {
  const BottomTabsScreen({super.key});

  @override
  ConsumerState<BottomTabsScreen> createState() => _BottomTabsScreenState();
}

class _BottomTabsScreenState extends ConsumerState<BottomTabsScreen> {
  /// The tabs being edited; null until first built from the saved ones.
  List<String>? _draft;
  bool _busy = false;

  Future<void> _save(List<String> draft) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(usersRepositoryProvider).setBottomTabs(me.id, bottomTabsToSave(draft, defaultBottomTabs(ref)));
      messenger.showSnackBar(SnackBar(content: Text(l10n.bottomTabsSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final options = bottomTabOptions(ref, l10n);
    final byPath = {for (final o in options) o.path: o};
    final current = [for (final t in myBottomTabs(ref, l10n)) t.path];
    final draft = _draft ??= List.of(current);
    draft.removeWhere((p) => !byPath.containsKey(p));
    final chosen = [for (final p in draft) byPath[p]!];
    final rest = [
      for (final o in options)
        if (!draft.contains(o.path)) o,
    ];
    final full = draft.length >= maxChosenTabs;
    final changed = !_listEquals(draft, current);
    final defaults = [
      for (final p in defaultBottomTabs(ref))
        if (byPath.containsKey(p)) p,
    ];
    final more = (icon: Icons.menu, label: l10n.more);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bottomTabs),
        actions: [
          TextButton(
            onPressed: _listEquals(draft, defaults) ? null : () => setState(() => _draft = List.of(defaults)),
            child: Text(l10n.resetToDefault),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // How the bar will look.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IgnorePointer(
                child: NavigationBar(
                  height: 64,
                  selectedIndex: 0,
                  destinations: [
                    for (final t in chosen)
                      NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.label),
                    NavigationDestination(icon: Icon(more.icon), label: more.label),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(l10n.bottomTabsHint, style: theme.textTheme.bodyMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(l10n.bottomTabsPhonesOnly, style: theme.textTheme.bodySmall),
          ),
          heading('${l10n.bottomTabsYours} (${draft.length + 1}/${maxChosenTabs + 1})'),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => setState(() => draft.insert(to, draft.removeAt(from))),
            children: [
              for (final (i, t) in chosen.indexed)
                Card(
                  key: ValueKey(t.path),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: ListTile(
                    leading: Icon(t.selected),
                    title: Text(t.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: draft.length <= 1 ? l10n.bottomTabsKeepOne : l10n.remove,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: theme.colorScheme.error,
                          onPressed: draft.length <= 1 ? null : () => setState(() => draft.remove(t.path)),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // More: always there, always last.
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(more.icon),
              title: Text(more.label),
              subtitle: Text(l10n.bottomTabsMoreFixed),
              trailing: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.lock_outline)),
            ),
          ),
          if (rest.isNotEmpty) ...[
            heading(l10n.bottomTabsAdd),
            if (full)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.bottomTabsFull,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            for (final o in rest)
              ListTile(
                enabled: !full,
                leading: Icon(o.icon),
                title: Text(o.label),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: full ? null : () => setState(() => draft.add(o.path)),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: FilledButton.icon(
              onPressed: !changed || _busy ? null : () => _save(List.of(draft)),
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

bool _listEquals(List<String> a, List<String> b) =>
    a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
