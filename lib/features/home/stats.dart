import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plan/plan_task.dart';
import '../visits/visit.dart';

/// A range of whole days, both ends included.
class StatsRange {
  StatsRange(DateTime start, DateTime end)
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day);

  factory StatsRange.month(DateTime d) => StatsRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1, 0));

  final DateTime start;
  final DateTime end;

  int get days => DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;

  List<DateTime> get dayList => [for (var i = 0; i < days; i++) DateTime(start.year, start.month, start.day + i)];

  bool contains(DateTime t) {
    final d = DateTime(t.year, t.month, t.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// Month keys ('yyyy-MM') the range touches, for `whereIn` queries.
  List<String> get months => [
        for (var m = DateTime(start.year, start.month); !m.isAfter(end); m = DateTime(m.year, m.month + 1))
          monthKey(m),
      ];

  @override
  bool operator ==(Object other) => other is StatsRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

int _daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// A monthly target spread over the days of [range], stopping after [until]
/// (e.g. today, for "expected so far").
double targetFor(int monthlyTarget, StatsRange range, {DateTime? until}) {
  if (monthlyTarget <= 0) return 0;
  var total = 0.0;
  for (final d in range.dayList) {
    if (until != null && d.isAfter(until)) break;
    total += monthlyTarget / _daysInMonth(d);
  }
  return total;
}

enum Pace { onTrack, slightlyBehind, behind }

/// Compares visits done with the target expected by now.
Pace paceOf(int done, double expected) {
  if (expected <= 0 || done >= expected) return Pace.onTrack;
  return done >= expected * 0.8 ? Pace.slightlyBehind : Pace.behind;
}

/// Visits in the given months; [ownerId] limits to one person (required for
/// sales execs by the security rules). Key: (ownerId, comma-joined months).
final rangeVisitsProvider = StreamProvider.family<List<Visit>, (String?, String)>((ref, key) {
  final months = key.$2.split(',');
  // One month (the usual case) as a plain equality: no composite index needed.
  Query<Map<String, dynamic>> q = months.length == 1
      ? FirebaseFirestore.instance.collection('visits').where('month', isEqualTo: months.single)
      : FirebaseFirestore.instance.collection('visits').where('month', whereIn: months);
  if (key.$1 != null) q = q.where('salesExecId', isEqualTo: key.$1);
  return q.snapshots().map((s) => s.docs.map(Visit.fromDoc).toList());
});

/// Plan tasks in the given months; same key as [rangeVisitsProvider].
final rangeTasksProvider = StreamProvider.family<List<PlanTask>, (String?, String)>((ref, key) {
  final months = key.$2.split(',');
  // One month (the usual case) as a plain equality: no composite index needed.
  Query<Map<String, dynamic>> q = months.length == 1
      ? FirebaseFirestore.instance.collection('tasks').where('month', isEqualTo: months.single)
      : FirebaseFirestore.instance.collection('tasks').where('month', whereIn: months);
  if (key.$1 != null) q = q.where('ownerId', isEqualTo: key.$1);
  return q.snapshots().map((s) => s.docs.map(PlanTask.fromDoc).toList());
});
