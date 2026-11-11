import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_user.dart';
import '../features/devices/phone_status_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/status_screens.dart';
import '../features/clients/given_items_widgets.dart';
import '../features/clients/client_tags.dart';
import '../features/clients/client_tags_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_edit_screen.dart';
import '../features/clients/clients_map_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/clients/visit_rules_screen.dart';
import '../features/home/bottom_tabs_screen.dart';
import '../features/home/app_shell.dart';
import '../features/home/home_screen.dart';
import '../features/home/more_screen.dart';
import '../features/import/import_screen.dart';
import '../features/import/location_import_screen.dart';
import '../features/hr/employee_leave_screen.dart';
import '../features/hr/hr_actions_screen.dart';
import '../features/hr/hr_screen.dart';
import '../features/attendance/absence_screen.dart';
import '../features/hr/leave_request_form.dart';
import '../features/hr/leave_request_screen.dart';
import '../features/hr/leave_rules.dart' show myLeaveEnabled;
import '../features/hr/my_leave_screen.dart';
import '../features/users/profile_screen.dart';
import '../features/users/user_form_screen.dart';
import '../features/users/user_log_screen.dart';
import '../features/users/org_chart_screen.dart';
import '../features/attendance/team_alerts_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/plan/plan_map_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/plan/team_plans_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/tracking/people_map_screen.dart';
import '../features/tracking/work_hours_screen.dart';
import '../features/visits/add_visit_screen.dart';
import '../features/visits/visit_detail_screen.dart';
import '../features/visits/visits_screen.dart';
import '../features/users/users_screen.dart';
import '../features/plan/plan_task.dart';
import 'providers.dart';
import '../features/clients/transfers_screen.dart';
import '../features/clients/catalogs_screen.dart';
import '../features/plan/team_plan_map_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/attendance/attendance_person_month_screen.dart';
import '../features/attendance/attendance_report_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/attendance/overtime_permission_screen.dart';
import '../features/attendance/work_sites_screen.dart';
import '../features/users/companies_screen.dart';
import '../features/settings/app_settings_screen.dart';
import '../features/settings/page_access.dart';
import '../features/settings/page_access_screen.dart';
import '../features/settings/tracking_schedules_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../features/documents/company_docs.dart' show DocSection;
import '../features/documents/company_docs_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.listen(pageAccessProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(currentUserProvider);
      final loc = state.matchedLocation;
      String? goTo(String path) => loc == path ? null : path;

      if (auth.isLoading) return goTo('/splash');
      if (auth.value == null) return loc == '/register' ? null : goTo('/login');
      if (profile.isLoading) return loc == '/register' ? null : goTo('/splash');

      final me = profile.value;
      // Just registered: the profile is being written.
      if (me == null && loc == '/register') return null;
      // Unknown role: a newer app version is needed (see UserRole.unknown).
      if (me == null || !me.active || me.role == UserRole.unknown) return goTo('/no-access');
      if (const ['/splash', '/login', '/register', '/no-access'].contains(loc)) return '/';
      // HR, accounting, procurement: no sales pages (clients, visits, plans, maps).
      if (me.can.isBackOffice &&
          !const ['/', '/more', '/profile', '/notifications', '/bottom-tabs'].contains(loc) &&
          !loc.startsWith('/leave') &&
          !loc.startsWith('/absence/') &&
          !loc.startsWith('/team-alerts') &&
          !loc.startsWith('/hr') &&
          !loc.startsWith('/attendance') &&
          !(me.can.canManageHr && loc == '/departments') &&
          // Logistics manager: the drivers' live map and route history; logistics
          // and factory managers: the Users page for their people.
          !(me.can.seesDrivers && (loc == '/drivers' || loc == '/history')) &&
          !(me.can.managesVehicles && loc.startsWith('/vehicles')) &&
          !(me.can.seesPhoneStatus && loc == '/phone-status') &&
          !(me.can.seesCompanyDocs && loc.startsWith('/documents')) &&
          !(me.can.managesUsers && loc.startsWith('/users'))) {
        return '/';
      }
      if (loc == '/drivers' && !me.can.seesDrivers) return '/';
      if (loc == '/phone-status' && !me.can.seesPhoneStatus) return '/';
      if (loc.startsWith('/vehicles') && !me.can.managesVehicles) return '/';
      if (loc.startsWith('/documents') && !me.can.seesCompanyDocs) return '/';
      if (loc.startsWith('/hr') && !me.can.canSeeHr) return '/';
      // Departments: HR edits them too (HR area → Leave types tab).
      if (loc == '/departments' && !me.can.canManageHr) return '/';
      // Managers and warehouse supervisors: the attendance of the people under them.
      if (loc.startsWith('/attendance') && !me.seesTeamAttendance) return '/';
      if (loc == '/attendance/map' && !me.seesEmployeesMap) return '/';
      // "My leave" is greyed out until finished; requests to approve still open.
      if (!myLeaveEnabled && (loc == '/leave' || loc == '/leave/new')) return '/';
      if (loc.startsWith('/users') && !me.can.managesUsers) return '/';
      if ((loc.startsWith('/import') || loc == '/visit-rules' || loc == '/given-items' || loc == '/client-tags' || loc == '/location-types' || loc == '/work-hours' || loc == '/work-sites' || loc == '/companies' || loc.startsWith('/settings')) && !me.can.isAdmin) return '/';
      if (const ['/live', '/reports', '/history', '/team-plans', '/team-plans/map', '/transfers', '/catalogs'].contains(loc) &&
          !me.can.isSupervisor &&
          !(me.can.seesDrivers && loc == '/history')) {
        return '/';
      }
      if (loc.startsWith('/plan/') && !me.can.isSupervisor && !loc.startsWith('/plan/${me.id}')) return '/';
      // Pages turned off for the role (App settings → Page access).
      if (!(ref.read(pageAccessProvider).value ?? PageAccess.defaults).allowsLocation(me, loc)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessScreen()),
      StatefulShellRoute(
        builder: (_, state, shell) => AppShell(shell: shell, location: state.uri.path),
        navigatorContainerBuilder: (_, shell, children) => BranchPager(shell: shell, children: children),
        branches: [
          StatefulShellBranch(preload: true, routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'plan/:uid',
                  builder: (_, state) => PlanScreen(
                    userId: state.pathParameters['uid']!,
                    initialDate: state.uri.queryParameters['date'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'map',
                      builder: (_, state) => PlanMapScreen(
                        userId: state.pathParameters['uid']!,
                        date: state.uri.queryParameters['date'] ?? dayKey(DateTime.now()),
                      ),
                    ),
                  ],
                ),
                GoRoute(path: 'notifications', builder: (_, _) => const NotificationsScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(preload: true, routes: [
            GoRoute(
              path: '/clients',
              builder: (_, _) => const ClientsScreen(),
              routes: [
                // Before ':id' so "new" isn't read as a client id.
                GoRoute(path: 'new', builder: (_, _) => const ClientEditScreen(clientId: null)),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => ClientDetailScreen(clientId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) => ClientEditScreen(clientId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'visit',
                      builder: (_, state) => AddVisitScreen(clientId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'call',
                      builder: (_, state) => AddVisitScreen(clientId: state.pathParameters['id']!, call: true),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(path: '/map', builder: (_, _) => const ClientsMapScreen()),
          ]),
          StatefulShellBranch(preload: true, routes: [
            GoRoute(
              path: '/visits',
              builder: (_, _) => const VisitsScreen(),
              routes: [
                // Before ':id' so "new" isn't read as a visit id.
                GoRoute(
                  path: 'new/:clientId',
                  builder: (_, state) => AddVisitScreen(clientId: state.pathParameters['clientId']!),
                ),
                GoRoute(
                  path: 'call/:clientId',
                  builder: (_, state) => AddVisitScreen(clientId: state.pathParameters['clientId']!, call: true),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => VisitDetailScreen(visitId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(preload: true, routes: [
            GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(path: '/bottom-tabs', builder: (_, _) => const BottomTabsScreen()),
            GoRoute(
              path: '/leave',
              builder: (_, _) => const MyLeaveScreen(),
              routes: [
                // Before ':id' so "new" isn't read as a request id.
                GoRoute(path: 'new', builder: (_, _) => const LeaveRequestForm()),
                GoRoute(path: ':id', builder: (_, state) => LeaveRequestScreen(id: state.pathParameters['id']!)),
              ],
            ),
            // Team follow-ups (2026-11-11): whoever was told (the data rules decide).
            GoRoute(
              path: '/team-alerts',
              builder: (_, _) => const TeamAlertsScreen(),
              routes: [
                GoRoute(path: ':id', builder: (_, state) => TeamAlertScreen(id: state.pathParameters['id']!)),
              ],
            ),
            GoRoute(path: '/absence/:id', builder: (_, state) => AbsenceScreen(id: state.pathParameters['id']!)),
            GoRoute(
              path: '/hr',
              builder: (_, _) => const HrScreen(),
              routes: [
                GoRoute(
                  path: 'employee/:uid',
                  builder: (_, state) => EmployeeLeaveScreen(
                    uid: state.pathParameters['uid']!,
                    year: int.tryParse(state.uri.queryParameters['year'] ?? ''),
                  ),
                ),
                // Warnings / deductions / rewards / notes (2026-11-07); 'new' before ':id'.
                GoRoute(path: 'action/new', builder: (_, state) => HrActionForm(uid: state.uri.queryParameters['uid'])),
                GoRoute(path: 'action/:id', builder: (_, state) => HrActionScreen(id: state.pathParameters['id']!)),
                GoRoute(path: 'action/:id/edit', builder: (_, state) => HrActionForm(id: state.pathParameters['id']!)),
              ],
            ),
            GoRoute(
              path: '/live',
              builder: (_, state) => PeopleMapScreen(
                mode: PeopleMapMode.live,
                onlyIds: state.uri.queryParameters['ids']?.split(',').where((id) => id.isNotEmpty).toSet(),
              ),
            ),
            // Phones' GPS, internet and permissions (2026-11-01).
            GoRoute(path: '/phone-status', builder: (_, _) => const PhoneStatusScreen()),
            // Drivers only (sales manager, GM, logistics manager).
            GoRoute(
              path: '/drivers',
              builder: (_, state) => PeopleMapScreen(
                mode: PeopleMapMode.drivers,
                onlyIds: state.uri.queryParameters['ids']?.split(',').where((id) => id.isNotEmpty).toSet(),
              ),
            ),
            // Vehicles: sales manager, GM, logistics manager (2026-10-24).
            GoRoute(
              path: '/vehicles',
              builder: (_, _) => const VehiclesScreen(),
              routes: [
                // Before ':id' so "new" isn't read as a vehicle id.
                GoRoute(path: 'new', builder: (_, _) => const VehicleEditScreen()),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => VehicleScreen(id: state.pathParameters['id']!),
                  routes: [
                    GoRoute(path: 'edit', builder: (_, state) => VehicleEditScreen(id: state.pathParameters['id']!)),
                  ],
                ),
              ],
            ),
            // Company documents (2026-11-01): the tree, one page per folder
            // (?s=section&c=company&f=folder), and a file's page.
            GoRoute(
              path: '/documents',
              builder: (_, state) => CompanyDocsScreen(
                section: DocSection.values.asNameMap()[state.uri.queryParameters['s']],
                companyId: state.uri.queryParameters['c'] ?? '',
                folderId: state.uri.queryParameters['f'] ?? '',
              ),
              routes: [
                GoRoute(path: 'file/:id', builder: (_, state) => CompanyDocScreen(id: state.pathParameters['id']!)),
              ],
            ),
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
            GoRoute(path: '/transfers', builder: (_, _) => const TransfersScreen()),
            GoRoute(path: '/catalogs', builder: (_, _) => const CatalogsScreen()),
            GoRoute(
              path: '/team-plans',
              builder: (_, state) => TeamPlansScreen(initialDate: state.uri.queryParameters['date']),
              routes: [
                GoRoute(
                  path: 'map',
                  builder: (_, state) => TeamPlanMapScreen(
                    date: state.uri.queryParameters['date'] ?? dayKey(DateTime.now()),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/history',
              // Everyone on the people map; `uid` opens that person's route.
              builder: (_, state) => PeopleMapScreen(
                mode: PeopleMapMode.history,
                personId: state.uri.queryParameters['uid'],
                date: state.uri.queryParameters['date'],
              ),
            ),
            GoRoute(path: '/visit-rules', builder: (_, _) => const VisitRulesScreen()),
            GoRoute(path: '/given-items', builder: (_, _) => const GivenItemRulesScreen()),
            GoRoute(path: '/client-tags', builder: (_, _) => const ClientTagsScreen()),
            GoRoute(
              path: '/location-types',
              builder: (_, _) => const ClientTagsScreen(kind: TagList.locationTypes),
            ),
            GoRoute(path: '/work-hours', builder: (_, _) => const WorkHoursScreen()),
            GoRoute(path: '/departments', builder: (_, _) => const ClientTagsScreen(kind: TagList.departments)),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const AppSettingsScreen(),
              routes: [
                GoRoute(path: 'tracking-schedules', builder: (_, _) => const TrackingSchedulesScreen()),
                GoRoute(path: 'page-access', builder: (_, _) => const PageAccessScreen()),
              ],
            ),
            GoRoute(path: '/work-sites', builder: (_, _) => const WorkSitesScreen()),
            GoRoute(path: '/companies', builder: (_, _) => const CompaniesScreen()),
            GoRoute(
              path: '/attendance',
              builder: (_, state) => AttendanceScreen(initialDate: DateTime.tryParse(state.uri.queryParameters['date'] ?? '')),
            ),
            GoRoute(path: '/attendance/map', builder: (_, _) => const PeopleMapScreen(mode: PeopleMapMode.employees)),
            GoRoute(path: '/attendance/overtime', builder: (_, _) => const OvertimePermissionScreen()),
            GoRoute(path: '/attendance/report', builder: (_, _) => const AttendanceReportScreen()),
            GoRoute(
              path: '/attendance/report/:uid',
              builder: (_, state) =>
                  AttendancePersonMonthScreen(uid: state.pathParameters['uid']!, month: state.uri.queryParameters['month']),
            ),
            GoRoute(
              path: '/import',
              builder: (_, _) => const ImportScreen(),
              routes: [
                GoRoute(path: 'locations', builder: (_, _) => const LocationImportScreen()),
              ],
            ),
            GoRoute(
              path: '/users',
              builder: (_, _) => const UsersScreen(),
              routes: [
                GoRoute(path: 'new', builder: (_, _) => const UserFormScreen(userId: null)),
                GoRoute(path: 'log', builder: (_, state) => UserLogScreen(userId: state.uri.queryParameters['uid'])),
                GoRoute(path: 'chart', builder: (_, _) => const OrgChartScreen()),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => UserFormScreen(userId: state.pathParameters['id']),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
