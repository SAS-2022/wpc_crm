import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/status_screens.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_edit_screen.dart';
import '../features/clients/clients_map_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/clients/visit_rules_screen.dart';
import '../features/home/app_shell.dart';
import '../features/home/home_screen.dart';
import '../features/home/more_screen.dart';
import '../features/import/import_screen.dart';
import '../features/import/location_import_screen.dart';
import '../features/users/user_form_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/plan/plan_map_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/reports/route_history_screen.dart';
import '../features/tracking/live_map_screen.dart';
import '../features/tracking/work_hours_screen.dart';
import '../features/visits/add_visit_screen.dart';
import '../features/visits/visit_detail_screen.dart';
import '../features/visits/visits_screen.dart';
import '../features/users/users_screen.dart';
import '../features/plan/plan_task.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
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
      if (auth.value == null) return goTo('/login');
      if (profile.isLoading) return goTo('/splash');

      final me = profile.value;
      if (me == null || !me.active) return goTo('/no-access');
      if (const ['/splash', '/login', '/no-access'].contains(loc)) return '/';
      if ((loc.startsWith('/users') || loc.startsWith('/import') || loc == '/visit-rules' || loc == '/work-hours') && !me.role.isAdmin) return '/';
      if (const ['/live', '/reports', '/history'].contains(loc) && !me.role.isSupervisor) return '/';
      if (loc.startsWith('/plan/') && !me.role.isSupervisor && !loc.startsWith('/plan/${me.id}')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, state, shell) => AppShell(shell: shell, location: state.uri.path),
        branches: [
          StatefulShellBranch(routes: [
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
          StatefulShellBranch(routes: [
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
                  ],
                ),
              ],
            ),
            GoRoute(path: '/map', builder: (_, _) => const ClientsMapScreen()),
          ]),
          StatefulShellBranch(routes: [
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
                  path: ':id',
                  builder: (_, state) => VisitDetailScreen(visitId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
            GoRoute(path: '/live', builder: (_, _) => const LiveMapScreen()),
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
            GoRoute(
              path: '/history',
              builder: (_, state) => RouteHistoryScreen(
                userId: state.uri.queryParameters['uid'],
                date: state.uri.queryParameters['date'],
              ),
            ),
            GoRoute(path: '/visit-rules', builder: (_, _) => const VisitRulesScreen()),
            GoRoute(path: '/work-hours', builder: (_, _) => const WorkHoursScreen()),
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
