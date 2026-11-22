import 'visit.dart';

/// Visits calendar (2026-11-22, user: like the attendance calendar, one
/// salesperson's visits and calls month by month).
class VisitMonth {
  VisitMonth({required this.month, required this.byDay});

  /// First day of the month.
  final DateTime month;

  /// Day of the month (1–31) → that day's visits and calls, earliest first.
  final Map<int, List<Visit>> byDay;

  Iterable<Visit> get all => byDay.values.expand((l) => l);
  int get visits => all.where((v) => !v.isCall).length;
  int get calls => all.where((v) => v.isCall).length;

  /// Days with at least one visit (calls alone don't count).
  int get fieldDays => byDay.values.where((l) => l.any((v) => !v.isCall)).length;

  /// Different clients visited or called.
  int get clients => all.map((v) => v.clientId).toSet().length;
}

/// [visits] of one person → their month (others outside it are left out).
/// A visit still waiting for its server time counts as [now].
VisitMonth visitMonth(Iterable<Visit> visits, DateTime month, {required DateTime now}) {
  final first = DateTime(month.year, month.month);
  final next = DateTime(month.year, month.month + 1);
  final byDay = <int, List<Visit>>{};
  for (final v in visits) {
    final t = v.checkedInAt ?? now;
    if (t.isBefore(first) || !t.isBefore(next)) continue;
    (byDay[t.day] ??= []).add(v);
  }
  for (final l in byDay.values) {
    l.sort((a, b) => (a.checkedInAt ?? now).compareTo(b.checkedInAt ?? now));
  }
  return VisitMonth(month: first, byDay: byDay);
}
