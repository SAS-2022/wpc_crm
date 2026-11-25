import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import 'attendance_repository.dart' show attendanceDay;

/// Overtime on a chosen day (2026-11-08, user: someone needed on a Friday
/// without making Friday one of their work days). A department head, the
/// SM / GM or HR (whoever may set overtime for the person,
/// `canSetOvertimeFor`) allows it for one person and one date. Firestore
/// `overtime_days/{uid}_{date}` {uid, date, month, note, byId, at}; the
/// server copies it onto the attendance day (`overtimeDay`) and the day
/// rules count it: a day off / holiday = arrival → leaving is all overtime;
/// a work day = the time after the end counts without "Start overtime".
/// The overtime still waits for the usual approval.
///
/// Assigned overtime (2026-11-25, user; drivers only, not forklift drivers):
/// [assignedMin] = the hours a manager gives the driver for that day. Then
/// staying late records nothing; the assigned minutes are the overtime,
/// approved at once (the server writes an `overtimeReview` with
/// `assigned: true`) and counted even without a check-in.
class OvertimeDay {
  const OvertimeDay(
      {required this.id, required this.uid, required this.date, this.note = '', this.byId = '', this.at, this.assignedMin});

  final String id;
  final String uid;

  /// 'yyyy-MM-dd'.
  final String date;
  final String note;
  final String byId;
  final DateTime? at;

  /// Assigned overtime minutes (drivers); null = the usual recorded overtime.
  final int? assignedMin;

  factory OvertimeDay.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return OvertimeDay(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      date: d['date'] as String? ?? '',
      note: d['note'] as String? ?? '',
      byId: d['byId'] as String? ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
      assignedMin: switch ((d['assignedMin'] as num?)?.toInt()) {
        final m? when m > 0 => m,
        _ => null,
      },
    );
  }
}

final _days = FirebaseFirestore.instance.collection('overtime_days');

/// Overtime days from 30 days ago on (managers / HR; the screen keeps
/// the people the viewer may set overtime for).
final overtimeDaysProvider = StreamProvider<List<OvertimeDay>>((ref) {
  final from = attendanceDay(DateTime.now().subtract(const Duration(days: 30)));
  return _days
      .where('date', isGreaterThanOrEqualTo: from)
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(OvertimeDay.fromDoc).toList());
});

/// The signed-in person's overtime day for today, if a manager allowed one.
final myOvertimeDayTodayProvider = StreamProvider<OvertimeDay?>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(null);
  return _days
      .doc('${me.id}_${attendanceDay(DateTime.now())}')
      .snapshots()
      .map((s) => s.exists ? OvertimeDay.fromDoc(s) : null);
});

final overtimeDaysRepositoryProvider = Provider((ref) => OvertimeDaysRepository());

class OvertimeDaysRepository {
  /// Allows overtime on [date] ('yyyy-MM-dd') for each of [people];
  /// [assignedMin]: assigned hours instead (drivers only).
  Future<void> allow(
          {required AppUser me,
          required List<AppUser> people,
          required String date,
          required String note,
          int? assignedMin}) =>
      saving(() async {
        final batch = FirebaseFirestore.instance.batch();
        for (final p in people) {
          batch.set(_days.doc('${p.id}_$date'), {
            'uid': p.id,
            'date': date,
            'month': date.substring(0, 7),
            'note': note,
            'byId': me.id,
            if (assignedMin != null && p.role == UserRole.driver) 'assignedMin': assignedMin,
            'at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });

  Future<void> remove(String id) => saving(() => _days.doc(id).delete());
}
