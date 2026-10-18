import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/given_items.dart';

void main() {
  const rules = GivenItemRules({GivenItem.switchCatalog: 30, GivenItem.bookletCatalog: 60, GivenItem.displayStand: 365});
  final now = DateTime(2026, 10, 18);
  GivenRecord given(int daysAgo) => GivenRecord(at: now.subtract(Duration(days: daysAgo)), qty: 1, total: 1);

  test('status: never, ok, due soon (last 14 days) and due', () {
    expect(givenStatus(null, GivenItem.switchCatalog, rules, now), GivenStatus.never);
    expect(givenStatus(given(5), GivenItem.switchCatalog, rules, now), GivenStatus.ok);
    expect(givenStatus(given(20), GivenItem.switchCatalog, rules, now), GivenStatus.dueSoon);
    expect(givenStatus(given(30), GivenItem.switchCatalog, rules, now), GivenStatus.due);
    expect(givenStatus(given(30), GivenItem.displayStand, rules, now), GivenStatus.ok);
    expect(givenNextDue(given(10), GivenItem.bookletCatalog, rules), now.add(const Duration(days: 50)));
  });

  test('rules fall back to the defaults for missing or bad values', () {
    final r = GivenItemRules.fromMap({'switchCatalog': 90, 'bookletCatalog': 0});
    expect(r.of(GivenItem.switchCatalog), 90);
    expect(r.of(GivenItem.bookletCatalog), GivenItemRules.defaults.of(GivenItem.bookletCatalog));
    expect(r.of(GivenItem.displayStand), GivenItemRules.defaults.of(GivenItem.displayStand));
  });

  test('visit quantities: only positive ones', () {
    expect(parseGiven({'switchCatalog': 2, 'displayStand': 0, 'unknown': 3}), {GivenItem.switchCatalog: 2});
    expect(parseGiven(null), isEmpty);
  });

  test('summary from the log plus the older summary: latest date and quantity, and the sum', () {
    final log = parseGivenLog([
      GivenEntry(id: 'a', item: GivenItem.switchCatalog, qty: 2, at: DateTime(2026, 9, 1), byId: 'u', visitId: 'v1').toMap(),
      // Backdated entry recorded on the client page.
      GivenEntry(id: 'b', item: GivenItem.switchCatalog, qty: 1, at: DateTime(2026, 3, 1), byId: 'k').toMap(),
      GivenEntry(id: 'c', item: GivenItem.displayStand, qty: 1, at: DateTime(2026, 10, 1), byId: 'u', visitId: 'v2').toMap(),
      {'item': 'unknown', 'qty': 1, 'at': Timestamp.fromDate(DateTime(2026, 1, 1))},
    ]);
    expect(log.map((e) => e.id), ['c', 'a', 'b']); // newest first, bad entry dropped
    expect(log.last.manual, isTrue);
    final legacy = {GivenItem.switchCatalog: GivenRecord(at: DateTime(2026, 5, 1), qty: 4, total: 4)};
    final sum = summarizeGiven(log, legacy);
    expect(sum[GivenItem.switchCatalog]!.at, DateTime(2026, 9, 1));
    expect(sum[GivenItem.switchCatalog]!.qty, 2);
    expect(sum[GivenItem.switchCatalog]!.total, 7);
    expect(sum[GivenItem.displayStand]!.total, 1);
    expect(sum.containsKey(GivenItem.bookletCatalog), isFalse);
  });

  test('visit entries: one per item given, keyed by the visit', () {
    final e = visitGivenEntries('v9', 'u', DateTime(2026, 10, 18), {GivenItem.bookletCatalog: 3});
    expect(e.single['id'], 'v9_bookletCatalog');
    expect(e.single['visitId'], 'v9');
    expect(visitGivenEntries('v9', 'u', DateTime(2026, 10, 18), const {}), isEmpty);
  });

  test('client record parsing', () {
    final r = GivenRecord.parse({
      'switchCatalog': {'at': Timestamp.fromDate(DateTime(2026, 10, 1)), 'qty': 2, 'total': 5},
    });
    expect(r[GivenItem.switchCatalog]!.total, 5);
    expect(r.containsKey(GivenItem.displayStand), isFalse);
  });
}
