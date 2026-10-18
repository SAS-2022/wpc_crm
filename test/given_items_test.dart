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

  test('rebuilt from visits: latest date and quantity, and the sum', () {
    final out = givenFromVisits([
      (at: DateTime(2026, 9, 1), given: {GivenItem.switchCatalog: 2}),
      (at: DateTime(2026, 10, 1), given: {GivenItem.switchCatalog: 1, GivenItem.displayStand: 1}),
      (at: DateTime(2026, 8, 1), given: const <GivenItem, int>{}),
    ]);
    expect(out.keys, unorderedEquals(['switchCatalog', 'displayStand']));
    final sw = out['switchCatalog']! as Map;
    expect((sw['at'] as Timestamp).toDate(), DateTime(2026, 10, 1));
    expect(sw['qty'], 1);
    expect(sw['total'], 3);
    expect(givenFromVisits(const []), isEmpty);
  });

  test('client record parsing', () {
    final r = GivenRecord.parse({
      'switchCatalog': {'at': Timestamp.fromDate(DateTime(2026, 10, 1)), 'qty': 2, 'total': 5},
    });
    expect(r[GivenItem.switchCatalog]!.total, 5);
    expect(r.containsKey(GivenItem.displayStand), isFalse);
  });
}
