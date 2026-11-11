import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/city_areas.dart';
import 'package:wpc_crm/features/attendance/work_sites.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/plan/plan_task.dart';
import 'package:wpc_crm/features/plan/team_plans_screen.dart' show planInRegion;
import 'package:wpc_crm/features/users/people_filter.dart';

const riyadh = (24.71, 46.67);
const dammam = (26.42, 50.09);

const sites = [
  WorkSite(id: 'sc', name: 'Wood Panels Service Center', lat: 24.71, lng: 46.67, companyId: 'wpc'),
  WorkSite(id: 'dm', name: 'Dammam Showroom', lat: 26.42, lng: 50.09, shortName: 'DMM', companyId: 'other'),
];

PlanTask task(String clientId) => PlanTask(
      id: clientId,
      ownerId: 'u',
      date: '2026-11-11',
      clientId: clientId,
      clientName: clientId,
      title: '',
      createdBy: 'u',
      approval: TaskApproval.approved,
      done: false,
      visitId: null,
    );

Client client(String id, (double, double) at) => Client(
      id: id,
      vat: '',
      nameKey: id,
      name: id,
      aliases: const [],
      phone: '',
      mobile: '',
      address: '',
      city: '',
      tags: '',
      odooSalesperson: '',
      googlePin: '',
      lat: at.$1,
      lng: at.$2,
      assignedTo: 'u',
      category: 'B',
      lastVisitAt: null,
    );

void main() {
  test('typed short names win, others are made from the name', () {
    final labels = siteChipLabels(sites);
    expect(labels['sc'], 'WPSC');
    expect(labels['dm'], 'DMM');
  });

  test('a clash with a typed short name keeps the full name of the automatic one', () {
    final labels = chipLabels(
      {'a': 'Wood Panels Co', 'b': 'Warehouse Plant'},
      {'b': 'WPC'},
    );
    expect(labels['b'], 'WPC');
    expect(labels['a'], 'Wood Panels Co');
  });

  test('sites of a company', () {
    expect(sitesOfCompany(sites, null).length, 2);
    expect(sitesOfCompany(sites, 'other').map((s) => s.id), ['dm']);
  });

  test('region: position first, then an assigned site, then the clients', () {
    expect(personInRegion(null, siteIds: const [], sites: sites), isTrue);
    expect(
      personInRegion(SaudiRegion.eastern, lat: dammam.$1, lng: dammam.$2, siteIds: const ['sc'], sites: sites),
      isTrue,
    );
    expect(personInRegion(SaudiRegion.central, siteIds: const ['sc'], sites: sites), isTrue);
    expect(personInRegion(SaudiRegion.eastern, siteIds: const ['sc'], sites: sites), isFalse);
    expect(
      personInRegion(SaudiRegion.eastern, siteIds: const [], sites: sites, territory: SaudiRegion.eastern),
      isTrue,
    );
  });

  test('team plan in a region: any planned stop there, else the territory', () {
    final clients = {'r': client('r', riyadh), 'd': client('d', dammam)};
    expect(planInRegion(SaudiRegion.eastern, [task('r'), task('d')], clients, null), isTrue);
    expect(planInRegion(SaudiRegion.western, [task('r')], clients, SaudiRegion.western), isFalse);
    expect(planInRegion(SaudiRegion.western, const [], clients, SaudiRegion.western), isTrue);
  });
}
