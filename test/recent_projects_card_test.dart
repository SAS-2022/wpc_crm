import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/home/dashboard_cards.dart';
import 'package:wpc_crm/features/projects/project.dart';
import 'package:wpc_crm/features/projects/projects_repository.dart';
import 'package:wpc_crm/features/settings/page_access.dart';
import 'package:wpc_crm/features/users/users_repository.dart';
import 'package:wpc_crm/l10n/app_localizations.dart';

AppUser user(UserRole role) =>
    AppUser(id: role.value, name: 'Person ${role.value}', email: '', phone: '', role: role, kamId: null, active: true);

// Newest first, as projectsProvider gives them.
final _projects = [
  for (var i = 5; i >= 1; i--) Project.fromMap('p$i', {'name': 'Project $i', 'contractor': 'Build $i', 'leadId': 'sales_exec'}),
];

Future<void> pump(WidgetTester tester, AppUser me, {PageAccess access = PageAccess.defaults, List<Project>? projects}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => Stream.value(projects ?? _projects)),
        usersProvider.overrideWith((ref) => Stream.value([me])),
        pageAccessProvider.overrideWith((ref) => Stream.value(access)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: RecentProjectsCard(me: me))),
      ),
    ));

void main() {
  testWidgets('shows the 3 most recent projects and "View all (5)"', (tester) async {
    await pump(tester, user(UserRole.salesExec));
    await tester.pumpAndSettle();
    expect(find.text('Latest projects'), findsOneWidget);
    for (final n in ['Project 5', 'Project 4', 'Project 3']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('Project 2'), findsNothing);
    expect(find.text('View all (5)'), findsOneWidget);
    // Order: newest first.
    expect(tester.getTopLeft(find.text('Project 5')).dy, lessThan(tester.getTopLeft(find.text('Project 3')).dy));
  });

  testWidgets('no projects: a note and "Add project"', (tester) async {
    await pump(tester, user(UserRole.kam), projects: const []);
    await tester.pumpAndSettle();
    expect(find.text('Add project'), findsOneWidget);
  });

  testWidgets('hidden for back-office roles', (tester) async {
    await pump(tester, user(UserRole.hr));
    await tester.pumpAndSettle();
    expect(find.text('Latest projects'), findsNothing);
  });

  testWidgets('hidden when Page access turns Projects off', (tester) async {
    await pump(tester, user(UserRole.salesExec),
        access: PageAccess.defaults.turned(AppPage.projects, UserRole.salesExec, false));
    await tester.pumpAndSettle();
    expect(find.text('Latest projects'), findsNothing);
  });
}
