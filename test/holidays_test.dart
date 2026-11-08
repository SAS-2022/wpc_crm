import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/hr/holidays.dart';

void main() {
  test('named holidays per year keep the dates list for everything else', () {
    final list = HolidayList.fromMap({
      'dates': ['2025-03-30', '2025-03-31', '2025-09-23'],
      'items': [
        {'id': 'a', 'name': 'Eid al-Fitr', 'from': '2025-03-30', 'to': '2025-03-31'},
      ],
    });
    expect(list.loose, {'2025-09-23'});
    expect(list.ofYear(2025).single.days, ['2025-03-30', '2025-03-31']);
    expect(list.missingNames(2026), ['Eid al-Fitr']);
    expect(list.lastOf('eid AL-fitr', 2026)?.year, 2025);

    // This year's Eid under the same name; naming a loose day drops it from loose.
    final next = list
        .put(const Holiday(id: 'b', name: 'Eid al-Fitr', from: '2026-03-20', to: '2026-03-22'))
        .put(const Holiday(id: 'c', name: 'National Day', from: '2025-09-23', to: '2025-09-23'));
    expect(next.loose, isEmpty);
    expect(next.missingNames(2026), ['National Day']);
    expect(next.toMap()['dates'],
        ['2025-03-30', '2025-03-31', '2025-09-23', '2026-03-20', '2026-03-21', '2026-03-22']);
    expect(HolidayList.fromMap(next.toMap()).items.length, 3);

    // Editing moves the dates; removing takes its days out.
    final moved = next.put(const Holiday(id: 'b', name: 'Eid al-Fitr', from: '2026-03-19', to: '2026-03-20'));
    expect(moved.dates.contains('2026-03-22'), isFalse);
    expect(moved.remove('a').dates.contains('2025-03-30'), isFalse);
  });
}
