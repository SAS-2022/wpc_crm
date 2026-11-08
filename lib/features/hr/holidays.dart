import 'leave_rules.dart';

/// A named public holiday of one year (2026-11-08, user: Eid al-Fitr and
/// Eid al-Adha move every year, so each year has its own dates under the
/// same name). [from] / [to] are 'yyyy-MM-dd', both included.
class Holiday {
  const Holiday({required this.id, required this.name, required this.from, required this.to});

  final String id;
  final String name;
  final String from;
  final String to;

  int get year => int.parse(from.substring(0, 4));

  /// Every day of the holiday ('yyyy-MM-dd').
  List<String> get days {
    final start = DateTime.parse(from);
    final end = DateTime.parse(to);
    return [
      for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) leaveDayKey(d),
    ];
  }

  Holiday copyWith({String? name, String? from, String? to}) =>
      Holiday(id: id, name: name ?? this.name, from: from ?? this.from, to: to ?? this.to);

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'from': from, 'to': to};

  static Holiday? fromMap(Object? m) {
    if (m is! Map) return null;
    final from = m['from'], to = m['to'];
    if (from is! String || DateTime.tryParse(from) == null) return null;
    final end = to is String && DateTime.tryParse(to) != null && to.compareTo(from) >= 0 ? to : from;
    return Holiday(id: m['id'] as String? ?? from, name: m['name'] as String? ?? '', from: from, to: end);
  }
}

/// Firestore `settings/holidays`: {items: [Holiday], dates: ['yyyy-MM-dd']}.
/// `dates` stays the full list of holiday days (the leave day count, the
/// attendance reminders and the server read only that); [loose] = days
/// entered before holidays had names (or without one).
class HolidayList {
  const HolidayList({this.items = const [], this.loose = const {}});

  final List<Holiday> items;
  final Set<String> loose;

  static const empty = HolidayList();

  factory HolidayList.fromMap(Map<String, dynamic>? d) {
    final items = [
      for (final m in d?['items'] as List<dynamic>? ?? const []) ?Holiday.fromMap(m),
    ];
    final named = {for (final h in items) ...h.days};
    final dates = {for (final x in d?['dates'] as List<dynamic>? ?? const []) if (x is String) x};
    return HolidayList(items: items, loose: dates.difference(named));
  }

  /// Every holiday day.
  Set<String> get dates => {...loose, for (final h in items) ...h.days};

  Map<String, dynamic> toMap() => {
        'items': [for (final h in sorted(items)) h.toMap()],
        'dates': dates.toList()..sort(),
      };

  /// The years that have a holiday.
  Set<int> get years => {for (final h in items) h.year, for (final d in loose) int.parse(d.substring(0, 4))};

  List<Holiday> ofYear(int year) => sorted(items.where((h) => h.year == year));

  List<String> looseOfYear(int year) => loose.where((d) => d.startsWith('$year-')).toList()..sort();

  /// Names used in other years and not yet in [year] (offered to add with this year's dates).
  List<String> missingNames(int year) {
    final here = {for (final h in ofYear(year)) _key(h.name)};
    final seen = <String>{};
    final out = <String>[];
    for (final h in sorted(items).reversed) {
      final k = _key(h.name);
      if (h.name.trim().isEmpty || here.contains(k) || !seen.add(k)) continue;
      out.add(h.name.trim());
    }
    return out..sort();
  }

  /// The same holiday in the closest year before [year], to show its old dates.
  Holiday? lastOf(String name, int year) {
    final k = _key(name);
    final before = sorted(items.where((h) => _key(h.name) == k && h.year < year));
    return before.isEmpty ? null : before.last;
  }

  /// Adds or replaces [h] (same id). Days in [loose] it now covers are dropped there.
  HolidayList put(Holiday h) {
    final list = [for (final x in items) if (x.id != h.id) x, h];
    return HolidayList(items: list, loose: loose.difference(h.days.toSet()));
  }

  HolidayList remove(String id) => HolidayList(items: [for (final x in items) if (x.id != id) x], loose: loose);

  HolidayList removeLoose(String day) => HolidayList(items: items, loose: {...loose}..remove(day));

  static List<Holiday> sorted(Iterable<Holiday> list) => list.toList()..sort((a, b) => a.from.compareTo(b.from));

  static String _key(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Saudi holidays offered as names (EN / AR).
const holidayNameSuggestions = {
  'en': ['Eid al-Fitr', 'Eid al-Adha', 'Founding Day', 'National Day'],
  'ar': ['عيد الفطر', 'عيد الأضحى', 'يوم التأسيس', 'اليوم الوطني'],
};
