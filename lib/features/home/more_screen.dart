import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../attendance/overtime.dart' show canSetOvertimeFor;
import '../hr/leave_rules.dart' show myLeaveEnabled;
import '../notifications/notifications.dart' show peopleUnder;
import '../users/users_repository.dart';
import '../settings/page_access.dart';
import '../../core/login_name.dart';
import '../../core/providers.dart';
import '../../core/sign_out.dart';
import '../../l10n/app_localizations.dart';

/// One tile of the More grid.
typedef _Item = ({IconData icon, String label, String path, VoidCallback onTap});

/// More tab: the role's tools as a grid in sections (user request
/// 2026-10-19: stays tidy as items are added), then language and sign out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    final role = me.can;
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    final users = ref.watch(usersProvider).value ?? const [];
    _Item item(IconData icon, String label, String path, {bool go = false}) =>
        (icon: icon, label: label, path: path, onTap: () => go ? context.go(path) : context.push(path));

    // Every page the person may open, on phones and on the web alike (user
    // request 2026-11-01: the sales manager sees all options here, also
    // those in the web side menu).
    final sections = <(String, List<_Item>)>[
      (l10n.moreSectionSales, [
        if (role.isTracked) item(Icons.today, l10n.myPlan, '/plan/${me.id}'),
        if (role.isSales) item(Icons.map, l10n.clientMap, '/map', go: true),
        if (role.isSupervisor) ...[
          item(Icons.groups, l10n.teamPlans, '/team-plans'),
          item(Icons.my_location, l10n.liveTracking, '/live'),
          item(Icons.table_chart, l10n.reports, '/reports'),
          item(Icons.swap_horiz, l10n.transferredClients, '/transfers'),
          item(Icons.style, l10n.catalogsPage, '/catalogs'),
          item(Icons.route, l10n.routeHistory, '/history'),
        ],
      ]),
      (l10n.moreSectionPeople, [
        if (myLeaveEnabled) item(Icons.beach_access, l10n.myLeave, '/leave'),
        // No Drivers tile (user request 2026-11-01): the live map has a
        // Drivers switch; the logistics manager / warehouse supervisor open
        // it from their Home card.
        // Department heads: Live tracking and Route history of their own
        // people (2026-11-14; KAM / SM / GM have them under Sales).
        if (!role.isSupervisor && me.seesLiveTracking) item(Icons.my_location, l10n.liveTracking, '/live'),
        if (!role.isSupervisor && me.seesRouteHistory) item(Icons.route, l10n.routeHistory, '/history'),
        if (me.seesPhoneStatus) item(Icons.phonelink_setup, l10n.phoneStatus, '/phone-status'),
        if (role.managesVehicles) item(Icons.directions_car_outlined, l10n.vehicles, '/vehicles'),
        if (me.seesTeamAttendance) item(Icons.how_to_reg, l10n.attendance, '/attendance'),
        if (me.seesEmployeesMap) item(Icons.person_pin_circle, l10n.employeesMap, '/attendance/map'),
        // Department heads / managers allow overtime per person (2026-11-05;
        // the Attendance app-bar icon alone was missed by the user).
        if (users.any((u) => u.checksAttendance && canSetOvertimeFor(me, u, users)))
          item(Icons.more_time, l10n.overtimePermission, '/attendance/overtime'),
        // Follow-ups on the team (2026-11-11): anyone with people under them.
        if (me.isManager || role.canManageHr || peopleUnder(me, users).isNotEmpty)
          item(Icons.assignment_late_outlined, l10n.teamAlerts, '/team-alerts'),
        if (role.canSeeHr) item(Icons.badge, l10n.hrArea, '/hr'),
        if (role.managesUsers) item(Icons.people, l10n.users, '/users'),
        if (role.managesUsers) item(Icons.account_tree_outlined, l10n.orgChart, '/users/chart'),
      ]),
      // Company documents (2026-11-01): the sales team, GM, SM and HR.
      (l10n.moreSectionCompany, [
        if (role.seesCompanyDocs) item(Icons.folder_copy_outlined, l10n.companyDocs, '/documents'),
      ]),
      (l10n.moreSectionSettings, [
        // Everyone picks their own bottom tabs (2026-11-08).
        item(Icons.space_dashboard_outlined, l10n.bottomTabs, '/bottom-tabs'),
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
              subtitle: Text('${[me.role, ...me.extraRoles].map((r) => r.label(l10n)).join(' + ')} · ${loginNameOf(me.email)}'),
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
