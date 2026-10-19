import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_calendar.dart';

void main() {
  // October 2026: the 1st is a Thursday. Work days Saturday–Thursday.
  const workDays = {DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday};
  final marks = markMonth(
    month: DateTime(2026, 10),
    attended: {'2026-10-04', '2026-10-05', '2026-10-21'},
    workDays: workDays,
    holidays: {'2026-10-08'},
    leaveDays: daysBetween('2026-10-11', '2026-10-12'),
    since: DateTime(2026, 10, 4),
    today: DateTime(2026, 10, 20, 15),
  );
  DayMark m(int day) => marks[DateTime(2026, 10, day)]!;

  test('every day of the month', () => expect(marks.length, 31));

  test('attended, missed, leave, holiday, weekend, before start, today, future', () {
    expect(m(4), DayMark.attended);
    expect(m(6), DayMark.missed);
    expect(m(8), DayMark.off); // holiday
    expect(m(9), DayMark.off); // Friday
    expect(m(11), DayMark.leave);
    expect(m(1), DayMark.none); // before attendance started
    expect(m(20), DayMark.today);
    expect(m(22), DayMark.future);
    expect(m(21), DayMark.attended); // a check-in always shows, even "in the future" (clock skew)
  });

  test('no start known: nothing is missed', () {
    final none = markMonth(
      month: DateTime(2026, 10),
      attended: const {},
      workDays: workDays,
      holidays: const {},
      leaveDays: const {},
      since: null,
      today: DateTime(2026, 10, 20),
    );
    expect(none.values.contains(DayMark.missed), isFalse);
  });

  test('days between', () {
    expect(daysBetween('2026-10-30', '2026-11-02'), {'2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02'});
    expect(daysBetween('2026-10-05', '2026-10-01'), isEmpty);
  });
}
