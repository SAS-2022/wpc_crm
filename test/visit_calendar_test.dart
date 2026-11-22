import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/visits/visit.dart';
import 'package:wpc_crm/features/visits/visit_calendar.dart';

Visit visit(String id, String clientId, DateTime? at, {VisitType type = VisitType.visit}) => Visit(
      id: id,
      clientId: clientId,
      clientName: clientId,
      salesExecId: 'a',
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      type: type,
    );

void main() {
  final now = DateTime(2026, 11, 22, 12);
  test('groups by day, earliest first, counts', () {
    final m = visitMonth([
      visit('1', 'c1', DateTime(2026, 11, 3, 15)),
      visit('2', 'c2', DateTime(2026, 11, 3, 9)),
      visit('3', 'c1', DateTime(2026, 11, 4, 10), type: VisitType.call),
      visit('4', 'c3', DateTime(2026, 10, 31, 10)),
      visit('5', 'c3', DateTime(2026, 12, 1)),
    ], DateTime(2026, 11, 15), now: now);
    expect(m.byDay.keys.toSet(), {3, 4});
    expect(m.byDay[3]!.map((v) => v.id), ['2', '1']);
    expect(m.visits, 2);
    expect(m.calls, 1);
    expect(m.fieldDays, 1);
    expect(m.clients, 2);
  });

  test('pending server time = now', () {
    final m = visitMonth([visit('1', 'c1', null)], DateTime(2026, 11), now: now);
    expect(m.byDay[22]!.length, 1);
  });
}
