import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/projects/project.dart';
import 'package:wpc_crm/features/settings/page_access.dart';

AppUser user(UserRole role, {bool active = true, List<UserRole> extra = const []}) =>
    AppUser(id: role.value, name: role.value, email: '', phone: '', role: role, kamId: null, active: active, extraRoles: extra);

void main() {
  test('reads a project document, old / missing fields defaulted', () {
    final p = Project.fromMap('p1', {
      'name': 'Tower A',
      'contractor': 'Build Co',
      'createdBy': 'u1',
      'clientIds': ['c1', 'c2'],
      'clientNames': {'c1': 'Alpha', 'c2': 'Beta'},
      'stage': 'samplesSubmitted',
      'materials': [
        {'id': 'm1', 'materialId': 'oak', 'status': 'approved'},
        {'id': 'm2', 'materialId': 'walnut'},
        'junk',
      ],
      'samples': [
        {'id': 's1', 'materialId': 'oak', 'day': '2026-11-10', 'qty': 3},
        {'id': 's2', 'materialId': '', 'day': '2026-11-12', 'note': 'Edge band'},
      ],
    });
    expect(p.leadId, 'u1', reason: 'no leadId = whoever added it');
    expect(p.stage, ProjectStage.samplesSubmitted);
    expect(p.hasLocation, isFalse);
    expect(p.materials.map((m) => m.status), [MaterialStatus.approved, MaterialStatus.proposed]);
    expect(p.sampleCount, 4);
    expect(p.samplesNewestFirst.first.id, 's2');
    expect(Project.fromMap('x', {'stage': 'weird'}).stage, ProjectStage.initiated);
  });

  test('a sample moves an initiated project to samples submitted only', () {
    expect(stageAfterSample(ProjectStage.initiated), ProjectStage.samplesSubmitted);
    for (final s in [ProjectStage.samplesSubmitted, ProjectStage.approved, ProjectStage.rejected]) {
      expect(stageAfterSample(s), s);
    }
  });

  test('who uses projects and who changes the lead', () {
    for (final r in [UserRole.salesExec, UserRole.kam, UserRole.salesManager, UserRole.gm]) {
      expect(canUseProjects(user(r)), isTrue, reason: r.value);
    }
    for (final r in [UserRole.hr, UserRole.worker, UserRole.driver, UserRole.accounting]) {
      expect(canUseProjects(user(r)), isFalse, reason: r.value);
    }
    expect(canUseProjects(user(UserRole.salesExec, active: false)), isFalse);
    expect(canUseProjects(user(UserRole.hr, extra: [UserRole.kam])), isTrue, reason: 'extra sales role');
    expect(canChangeProjectLead(user(UserRole.salesManager)), isTrue);
    expect(canChangeProjectLead(user(UserRole.gm)), isTrue);
    expect(canChangeProjectLead(user(UserRole.kam)), isFalse);
    expect(canChangeProjectLead(user(UserRole.salesExec)), isFalse);
  });

  test('client filter by project and stage', () {
    final projects = [
      Project.fromMap('a', {'name': 'A', 'clientIds': ['c1', 'c2'], 'stage': 'initiated'}),
      Project.fromMap('b', {'name': 'B', 'clientIds': ['c2', 'c3'], 'stage': 'approved'}),
    ];
    final none = projectClientFilter(projects, {}, {});
    expect(none('c9'), isTrue, reason: 'no filter = every client');
    final byId = projectClientFilter(projects, {'a'}, {});
    expect(['c1', 'c2', 'c3'].where(byId), ['c1', 'c2']);
    final byStage = projectClientFilter(projects, {}, {ProjectStage.approved});
    expect(['c1', 'c2', 'c3'].where(byStage), ['c2', 'c3']);
    final both = projectClientFilter(projects, {'a'}, {ProjectStage.approved});
    expect(['c1', 'c2', 'c3'].where(both), isEmpty);
    expect(filteredProjects(projects, {}, {}), isEmpty, reason: 'no project pins without a filter');
    expect(filteredProjects(projects, {}, {ProjectStage.initiated}).map((p) => p.id), ['a']);
  });

  test('search on name, companies, contacts, client names and phones (Arabic folded)', () {
    final p = Project.fromMap('a', {
      'name': 'برج الأمل',
      'contractor': 'Build Co',
      'parties': [
        {'id': '1', 'kind': 'contractor', 'name': 'Build Co'},
        {
          'id': '2',
          'kind': 'designer',
          'name': 'Studio Noor',
          'contacts': [
            {'name': 'Sara', 'title': 'Lead designer', 'phone': '+966 55 123 4567'},
          ],
        },
      ],
      'clientNames': {'c1': 'Alpha Interiors'},
    });
    expect(projectMatches(p, 'امل'), isTrue);
    expect(projectMatches(p, 'build'), isTrue);
    expect(projectMatches(p, 'noor'), isTrue);
    expect(projectMatches(p, 'sara'), isTrue);
    expect(projectMatches(p, 'interiors'), isTrue);
    expect(projectMatches(p, '1234567'), isTrue);
    expect(projectMatches(p, 'zzz'), isFalse);
    expect(projectMatches(p, ''), isTrue);
  });

  test('companies with several contacts; the first named contractor is the main one', () {
    final p = Project.fromMap('a', {
      'parties': [
        {'id': '1', 'kind': 'designer', 'name': 'Studio Noor', 'contacts': [{'name': 'Sara'}, {'name': 'Omar'}]},
        {'id': '2', 'kind': 'contractor', 'name': ' '},
        {'id': '3', 'kind': 'contractor', 'name': 'Build Co'},
        {'id': '4', 'kind': 'consultant', 'name': 'Dar Consult'},
        {'id': '5', 'kind': 'unknown', 'name': 'x'},
      ],
    });
    expect(p.parties.length, 4, reason: 'unknown kinds dropped');
    expect(p.partiesOf(PartyKind.designer).single.contacts.map((c) => c.name), ['Sara', 'Omar']);
    expect(p.partiesOf(PartyKind.contractor).length, 2);
    expect(mainContractorName(p.parties), 'Build Co');
    expect(mainContractorName(const []), '');
    // Empty contacts aren't saved; names are trimmed.
    final party = ProjectParty(id: 'x', kind: PartyKind.consultant, name: ' Dar ', contacts: const [
      PartyContact(name: 'Ali', phone: '055'),
      PartyContact(name: ' '),
    ]);
    final map = party.toMap();
    expect(map['name'], 'Dar');
    expect((map['contacts'] as List).length, 1);
    expect(ProjectParty.fromMap(map)!.contacts.single.phone, '055');
  });

  test('Projects page: sales roles only, and it can be turned off', () {
    expect(AppPage.forLocation('/projects/abc/edit'), AppPage.projects);
    expect(PageAccess.defaults.allows(UserRole.salesExec, AppPage.projects), isTrue);
    expect(PageAccess.defaults.allows(UserRole.hr, AppPage.projects), isFalse);
    final off = PageAccess.defaults.turned(AppPage.projects, UserRole.salesExec, false);
    expect(off.allows(UserRole.salesExec, AppPage.projects), isFalse);
    expect(AppPage.forLocation('/products'), AppPage.products);
    expect(PageAccess.defaults.allows(UserRole.hr, AppPage.products), isFalse);
  });
}
