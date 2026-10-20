import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/given_items.dart';
import 'package:wpc_crm/features/home/stats.dart';
import 'package:wpc_crm/features/reports/report_sections.dart';
import 'package:wpc_crm/features/visits/visit.dart';

AppUser user(String id) => AppUser(id: id, name: id, email: '', phone: '', role: UserRole.salesExec, kamId: null, active: true);

Client client(String id, {String? owner, String source = 'import', String createdBy = '', DateTime? createdAt, List<GivenEntry> log = const []}) =>
    Client(
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
      lat: 24.7,
      lng: 46.6,
      assignedTo: owner,
      category: 'B',
      lastVisitAt: null,
      source: source,
      createdBy: createdBy,
      createdAt: createdAt,
      givenLog: log,
      given: summarizeGiven(log, const {}),
    );

Visit visit(String id, String by, DateTime at, double lng) => Visit(
      id: id,
      clientId: 'x',
      clientName: 'x',
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      checkInLat: 24.7,
      checkInLng: lng,
    );

void main() {
  final range = StatsRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
  final sami = user('sami'), eddy = user('eddy');

  test('new clients: added in the app by the people, or imported for them', () {
    final r = newClientsReport(
      clients: [
        client('a', owner: 'sami', source: 'manual', createdBy: 'sami', createdAt: DateTime(2026, 10, 5)),
        client('b', owner: 'sami', createdAt: DateTime(2026, 10, 9)),
        client('c', createdAt: DateTime(2026, 10, 9)), // imported, nobody's
        client('d', owner: 'omar', source: 'manual', createdBy: 'omar', createdAt: DateTime(2026, 10, 9)),
        client('e', owner: 'sami', source: 'manual', createdBy: 'sami', createdAt: DateTime(2026, 9, 30)),
      ],
      people: {'sami'},
      range: range,
    );
    expect(r.clients.map((c) => c.id), ['b', 'a']);
    expect(r.manual, 1);
    expect(r.imported, 1);
    expect(r.addedBy, {'sami': 1});
    final all = newClientsReport(clients: [client('c', createdAt: DateTime(2026, 10, 9))], people: {'sami'}, range: range, includeUnowned: true);
    expect(all.clients.single.id, 'c');
  });

  test('routing: days with two or more visits, calls and other people left out', () {
    final d1 = DateTime(2026, 10, 5, 9);
    final rows = routingReport(
      people: [sami, eddy],
      visits: [
        visit('1', 'sami', d1, 46.60),
        visit('2', 'sami', d1.add(const Duration(hours: 1)), 46.64),
        visit('3', 'sami', d1.add(const Duration(hours: 2)), 46.61), // back and forth
        visit('4', 'sami', DateTime(2026, 10, 6, 9), 46.6), // single visit day: skipped
        visit('5', 'eddy', d1, 46.6),
      ],
      clients: const {},
      range: range,
    ).rows;
    expect(rows.first.days.length, 1);
    expect(rows.first.days.single.visits, 3);
    expect(rows.first.bestOrderDays, 0);
    expect(rows.first.extraMeters, greaterThan(0));
    expect(rows.first.averageRate, inInclusiveRange(0.0, 1.0));
    expect(rows.last.days, isEmpty);
    expect(rows.last.averageRate, isNull);
  });

  test('catalogs: per person and item in the period, due and never given', () {
    GivenEntry e(String id, GivenItem item, int qty, DateTime at, String by) =>
        GivenEntry(id: id, item: item, qty: qty, at: at, byId: by);
    final clients = [
      client('a', owner: 'sami', log: [
        e('1', GivenItem.switchCatalog, 2, DateTime(2026, 10, 3), 'sami'),
        e('2', GivenItem.displayStand, 1, DateTime(2026, 10, 4), 'eddy'),
        e('3', GivenItem.switchCatalog, 5, DateTime(2025, 1, 1), 'sami'), // old: due, not counted
      ]),
      client('b', owner: 'sami', log: [e('4', GivenItem.a4Samples, 3, DateTime(2026, 10, 8), 'sami')]),
    ];
    final r = catalogReport(people: [sami, eddy], clients: clients, range: range, rules: GivenItemRules.defaults, now: DateTime(2026, 10, 18));
    expect(r.rows.first.byItem, {GivenItem.switchCatalog: 2, GivenItem.a4Samples: 3});
    expect(r.rows.first.clients, 2);
    expect(r.rows.first.total, 5);
    expect(r.rows.last.byItem, {GivenItem.displayStand: 1});
    expect(r.neverGiven[GivenItem.bookletCatalog], 2);
    expect(r.dueNow[GivenItem.switchCatalog], 0); // latest switch catalog is from Oct 2026
  });

  test('catalogs: visits saved by older apps (no log entry) count too, logged ones once', () {
    Visit gave(String id, String by, DateTime at, Map<GivenItem, int> given) => Visit(
          id: id,
          clientId: 'c$id',
          clientName: '',
          salesExecId: by,
          checkedInAt: at,
          notes: '',
          distanceMeters: null,
          accuracy: null,
          mocked: false,
          given: given,
        );
    final clients = [
      client('a', owner: 'sami', log: [
        GivenEntry(id: 'v1_switchCatalog', item: GivenItem.switchCatalog, qty: 2, at: DateTime(2026, 10, 3), byId: 'sami', visitId: 'v1'),
      ]),
    ];
    final r = catalogReport(
      people: [sami],
      clients: clients,
      visits: [
        gave('v1', 'sami', DateTime(2026, 10, 3), {GivenItem.switchCatalog: 2}), // in the log already
        gave('v2', 'sami', DateTime(2026, 10, 18), {GivenItem.switchCatalog: 3, GivenItem.displayStand: 1}),
        gave('v3', 'sami', DateTime(2026, 9, 18), {GivenItem.switchCatalog: 9}), // before the period
      ],
      range: range,
      rules: GivenItemRules.defaults,
      now: DateTime(2026, 10, 18),
    );
    expect(r.rows.single.byItem, {GivenItem.switchCatalog: 5, GivenItem.displayStand: 1});
    expect(r.rows.single.clients, 2);
  });
}
