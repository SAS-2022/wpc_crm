import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/visit_rules.dart';
import 'package:wpc_crm/features/import/odoo_parser.dart';

Client client(String category, DateTime? lastVisit) => Client(
      id: 'c', vat: '', nameKey: 'c', name: 'C', aliases: const [], phone: '', mobile: '', address: '',
      city: '', tags: '', odooSalesperson: '', googlePin: '', lat: 1, lng: 1, assignedTo: null,
      category: category, lastVisitAt: lastVisit,
    );

void main() {
  final now = DateTime(2026, 10, 30);
  DateTime ago(int days) => now.subtract(Duration(days: days));
  const rules = VisitRules.defaults;

  test('category A: green up to 7 days, yellow up to 14, then red', () {
    expect(visitStatus(client('A', ago(7)), rules, now), VisitStatus.recent);
    expect(visitStatus(client('A', ago(8)), rules, now), VisitStatus.dueSoon);
    expect(visitStatus(client('A', ago(14)), rules, now), VisitStatus.dueSoon);
    expect(visitStatus(client('A', ago(15)), rules, now), VisitStatus.overdue);
  });

  test('B and C allow longer gaps; never visited is overdue', () {
    expect(visitStatus(client('B', ago(14)), rules, now), VisitStatus.recent);
    expect(visitStatus(client('C', ago(30)), rules, now), VisitStatus.recent);
    expect(visitStatus(client('C', ago(40)), rules, now), VisitStatus.dueSoon);
    expect(visitStatus(client('C', null), rules, now), VisitStatus.overdue);
  });

  test('rules read from settings, with defaults for missing categories', () {
    final r = VisitRules.fromMap({'A': {'green': 5, 'yellow': 10}});
    expect(r.of('A').greenDays, 5);
    expect(r.of('C').yellowDays, 45);
    expect(VisitRules.fromMap(r.toMap()).of('A').yellowDays, 10);
  });

  test('Category column values', () {
    expect(parseCategory('a'), 'A');
    expect(parseCategory(' Category B '), 'B');
    expect(parseCategory('class c'), 'C');
    expect(parseCategory('D'), '');
    expect(parseCategory(''), '');
  });
}
