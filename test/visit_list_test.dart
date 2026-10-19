import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/visits/visit.dart';
import 'package:wpc_crm/features/visits/visits_screen.dart';

Visit _v(String id, String by, DateTime at, {VisitType type = VisitType.visit}) => Visit(
      id: id,
      clientId: 'c',
      clientName: 'c',
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      type: type,
    );

void main() {
  final now = DateTime(2026, 10, 17, 18);

  test('same-day visit: own visits to the client on that date, calls left out', () {
    final day = DateTime(2026, 10, 17, 16);
    expect(sameDayVisit([_v('1', 's', DateTime(2026, 10, 17, 9))], 's', day)?.id, '1');
    expect(sameDayVisit([_v('1', 's', DateTime(2026, 10, 16, 23))], 's', day), isNull);
    expect(sameDayVisit([_v('1', 'a', DateTime(2026, 10, 17, 9))], 's', day), isNull);
    expect(sameDayVisit([_v('1', 's', DateTime(2026, 10, 17, 9), type: VisitType.call)], 's', day), isNull);
  });
  const names = {'s': 'Sami', 'a': 'Ahmad'};
  // Newest first, as the list provider gives them.
  final list = [
    _v('1', 's', DateTime(2026, 10, 17, 15)),
    _v('2', 'a', DateTime(2026, 10, 17, 14), type: VisitType.call),
    _v('3', 's', DateTime(2026, 10, 17, 10)),
    _v('4', 'a', DateTime(2026, 10, 16, 9)),
  ];

  test('by day, then by salesperson (by name), newest first inside', () {
    final items = visitListItems(list, now: now, byPerson: true, nameOf: (u) => names[u]!);
    expect(items.map((i) => switch (i) {
          final DateTime d => 'day ${d.day}',
          final PersonGroup g => '${g.uid} ${g.visits}v ${g.calls}c',
          final Visit v => v.id,
          _ => '?',
        }), [
      'day 17',
      'a 0v 1c',
      '2',
      's 2v 0c',
      '1',
      '3',
      'day 16',
      'a 1v 0c',
      '4',
    ]);
  });

  test('without grouping by person: day headers only', () {
    final items = visitListItems(list, now: now, byPerson: false, nameOf: (u) => names[u]!);
    expect(items.whereType<PersonGroup>(), isEmpty);
    expect(items.whereType<DateTime>().length, 2);
    expect(items.whereType<Visit>().map((v) => v.id), ['1', '2', '3', '4']);
  });
}
