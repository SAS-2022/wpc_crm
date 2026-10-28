import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'work_hours.dart';

/// Office staff GPS recording (2026-10-28, user: "start at 8 and end at
/// 6"): these hours on their work days ([AppUser.recordsGps]).
const recordStartMinute = 8 * 60;
const recordEndMinute = 18 * 60;

/// Recording hours on [days] (their own attendance days or the company's).
WorkHours recordingHours(Set<int> days) =>
    WorkHours(days: days, startMinute: recordStartMinute, endMinute: recordEndMinute);

/// When one person's location is shared (2026-10-21, App settings →
/// Tracking schedules): the company work hours (drivers: all day), their own
/// days / hours, or all day.
enum TrackingMode { standard, own, allDay }

/// A person's tracking schedule from RTDB `settings/trackingSchedules/{uid}`:
/// {mode: 'allDay'} or {mode: 'own', days, start, end}; no entry = standard.
/// Same rules as `trackingHours` in functions/index.js.
class TrackingSchedule {
  const TrackingSchedule.own(WorkHours this.hours) : mode = TrackingMode.own;
  const TrackingSchedule.allDay()
      : mode = TrackingMode.allDay,
        hours = null;
  const TrackingSchedule.standard()
      : mode = TrackingMode.standard,
        hours = null;

  final TrackingMode mode;

  /// Only for [TrackingMode.own].
  final WorkHours? hours;

  /// Standard when [value] is missing or not valid.
  factory TrackingSchedule.fromMap(Object? value) {
    if (value is! Map) return const TrackingSchedule.standard();
    if (value['mode'] == 'allDay') return const TrackingSchedule.allDay();
    final hours = WorkHours.tryParse(value);
    return hours == null || hours.days.isEmpty ? const TrackingSchedule.standard() : TrackingSchedule.own(hours);
  }

  /// Null for standard (the entry is removed).
  Map<String, Object>? toMap() => switch (mode) {
        TrackingMode.standard => null,
        TrackingMode.allDay => {'mode': 'allDay'},
        TrackingMode.own => {'mode': 'own', ...hours!.toMap()},
      };

  /// Whether the location is shared at [now]. Drivers keep the company car,
  /// so their standard is all day (user decision 2026-10-20). Office staff
  /// ([recordOnly]): 08:00–18:00 on [days] (null = the company's days).
  bool isOn(DateTime now, WorkHours company, {required bool driver, bool recordOnly = false, Set<int>? days}) =>
      switch (mode) {
        TrackingMode.allDay => true,
        TrackingMode.own => hours!.isOn(now),
        TrackingMode.standard =>
          driver || (recordOnly ? recordingHours(days ?? company.days) : company).isOn(now),
      };
}

DatabaseReference get trackingSchedulesRef => FirebaseDatabase.instance.ref('settings/trackingSchedules');

DatabaseReference trackingScheduleRef(String uid) => trackingSchedulesRef.child(uid);

/// Everyone's schedule by uid (only people with their own entry).
final trackingSchedulesProvider = StreamProvider<Map<String, TrackingSchedule>>(
  (ref) => trackingSchedulesRef.onValue.map((event) {
    final value = event.snapshot.value;
    if (value is! Map) return const {};
    return {for (final e in value.entries) '${e.key}': TrackingSchedule.fromMap(e.value)};
  }),
);
