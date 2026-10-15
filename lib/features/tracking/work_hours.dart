import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saudi Arabia is UTC+3 all year (no daylight saving).
const _saudiOffset = Duration(hours: 3);

/// When field staff locations are shared (user decision: Saturday to
/// Thursday, Friday off). Outside these hours nothing is sent. Set by the
/// GM / sales manager in More → Work hours; stored in RTDB
/// `settings/workHours` so the Android background service can read it too.
class WorkHours {
  const WorkHours({required this.days, required this.startMinute, required this.endMinute});

  /// Saturday to Thursday, 08:00–17:00 Saudi time (user decision 2026-10-16).
  static const defaults = WorkHours(
    days: {DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday},
    startMinute: 8 * 60,
    endMinute: 17 * 60,
  );

  /// Working weekdays, as [DateTime.weekday] (Monday = 1 … Sunday = 7).
  final Set<int> days;

  /// Minutes after midnight, Saudi time; [endMinute] is after [startMinute].
  final int startMinute;
  final int endMinute;

  /// [now] in Saudi time.
  static DateTime saudiTime(DateTime now) => now.toUtc().add(_saudiOffset);

  bool isOn(DateTime now) {
    final t = saudiTime(now);
    final minute = t.hour * 60 + t.minute;
    return days.contains(t.weekday) && minute >= startMinute && minute < endMinute;
  }

  factory WorkHours.fromMap(Object? value) {
    if (value is! Map<Object?, Object?>) return defaults;
    final days = value['days'];
    final start = value['start'];
    final end = value['end'];
    if (days is! List || start is! num || end is! num || end <= start) return defaults;
    return WorkHours(
      days: {for (final d in days) if (d is num && d >= 1 && d <= 7) d.toInt()},
      startMinute: start.toInt(),
      endMinute: end.toInt(),
    );
  }

  Map<String, Object> toMap() => {'days': (days.toList()..sort()), 'start': startMinute, 'end': endMinute};
}

DatabaseReference get workHoursRef => FirebaseDatabase.instance.ref('settings/workHours');

final workHoursProvider = StreamProvider<WorkHours>(
  (ref) => workHoursRef.onValue.map((event) => WorkHours.fromMap(event.snapshot.value)),
);
