import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/catalog_monitor.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/given_items.dart';
import 'package:wpc_crm/features/home/stats.dart';
import 'package:wpc_crm/features/visits/visit.dart';

Client client(String id, {List<GivenEntry> log = const []}) => Client(
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
      assignedTo: 'sami',
      category: 'B',
      lastVisitAt: null,
      givenLog: log,
      given: summarizeGiven(log, const {}),
    );

GivenEntry e(String id, GivenItem item, int qty, DateTime at, String by, {String? visitId}) =>
    GivenEntry(id: id, item: item, qty: qty, at: at, byId: by, visitId: visitId);

Visit visit(String id, String clientId, DateTime at,
        {String by = 'sami', bool call = false, Map<GivenItem, int> given = const {}}) =>
    Visit(
      id: id,
      clientId: clientId,
      clientName: clientId,
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      type: call ? VisitType.call : VisitType.visit,
      given: given,
    );

void main() {
  final now = DateTime(2026, 11, 1);

  test('client rows: only clients who got the item, visit totals and the last visit', () {
    final clients = [
      client('a', log: [
        e('1', GivenItem.switchCatalog, 2, DateTime(2026, 10, 3), 'sami'),
        e('2', GivenItem.displayStand, 1, DateTime(2025, 6, 1), 'sami'), // 365 days → due
      ]),
      client('b', log: [e('3', GivenItem.a4Samples, 3, DateTime(2026, 10, 20), 'eddy')]),
      client('c'),
    ];
    final visits = [
      visit('v1', 'a', DateTime(2026, 9, 1)),
      visit('v2', 'a', DateTime(2026, 10, 3)),
      visit('v3', 'a', DateTime(2026, 10, 25), call: true),
      visit('v4', 'b', DateTime(2026, 10, 20)),
    ];
    final all = catalogClientRows(clients: clients, visits: visits, rules: GivenItemRules.defaults, now: now);
    expect(all.map((r) => r.client.id), ['b', 'a']); // newest hand-over first, c never got one
    final a = all.last;
    expect(a.visits, 2);
    expect(a.calls, 1);
    expect(a.lastVisitAt, DateTime(2026, 10, 3)); // the call isn't a visit
    expect(a.status, GivenStatus.due); // the stand is overdue
    expect(a.lastGivenAt, DateTime(2026, 10, 3));

    final stands = catalogClientRows(
        clients: clients, visits: visits, rules: GivenItemRules.defaults, now: now, item: GivenItem.displayStand);
    expect(stands.single.client.id, 'a');
    expect(stands.single.items.keys, [GivenItem.displayStand]);
  });

  test('hand-overs in a period: log entries plus visits of older apps, once each', () {
    final range = StatsRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    final clients = [
      client('a', log: [
        e('v1_switchCatalog', GivenItem.switchCatalog, 2, DateTime(2026, 10, 3), 'sami', visitId: 'v1'),
        e('m1', GivenItem.bookletCatalog, 1, DateTime(2026, 9, 30), 'sami'), // before the period
      ]),
      client('b', log: [e('m2', GivenItem.a4Samples, 3, DateTime(2026, 10, 20), 'eddy')]),
    ];
    final visits = [
      visit('v1', 'a', DateTime(2026, 10, 3), given: {GivenItem.switchCatalog: 2}), // logged already
      visit('v2', 'b', DateTime(2026, 10, 10), by: 'sami', given: {GivenItem.displayStand: 1}), // older app
    ];
    final list = handoversIn(clients: clients, visits: visits, range: range);
    expect(list.map((h) => (h.client.id, h.item, h.qty)), [
      ('b', GivenItem.a4Samples, 3),
      ('b', GivenItem.displayStand, 1),
      ('a', GivenItem.switchCatalog, 2),
    ]);
    expect(list[1].atVisit, isTrue);
    expect(list.first.atVisit, isFalse);

    final totals = handoverTotals(list);
    expect(totals.first.byId, 'eddy'); // 3 items
    expect(totals.first.total, 3);
    expect(totals.last.byItem, {GivenItem.displayStand: 1, GivenItem.switchCatalog: 2});
    expect(totals.last.clientIds, {'a', 'b'});
  });
}
