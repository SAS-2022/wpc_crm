import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../tracking/work_hours.dart';
import 'attendance_rules.dart';

// Attendance days in Firestore `attendance/{uid}_{yyyy-MM-dd}`: {uid, date,
// month, events[]} written by the phone; checkInAt, checkOutAt, checkOutType,
// inside, workedMin, countedMin, overtimeMin, closed… by Cloud Functions.

String attendanceDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DocumentReference<Map<String, dynamic>> attendanceDoc(String uid, String day) =>
    FirebaseFirestore.instance.collection('attendance').doc('${uid}_$day');

/// Adds one event to today's attendance; works offline (sent later).
/// [extra]: details kept on the event for checking later (e.g. the GPS
/// distance that confirmed a geofence event); the server ignores them.
Future<void> recordAttendance(String uid, AttendanceEventType type, {String? siteId, DateTime? at, Map<String, Object>? extra}) {
  final when = at ?? DateTime.now();
  final day = attendanceDay(when);
  return attendanceDoc(uid, day).set({
    'uid': uid,
    'date': day,
    'month': day.substring(0, 7),
    'events': FieldValue.arrayUnion([
      {'type': eventTypeKey(type), 'at': Timestamp.fromDate(when), 'siteId': ?siteId, ...?extra},
    ]),
  }, SetOptions(merge: true));
}

/// One person's day as stored (events + the server's result).
class AttendanceRecord {
  const AttendanceRecord({required this.uid, required this.date, required this.events, required this.server});

  final String uid;
  final String date;
  final List<AttendanceEvent> events;

  /// The server's result; null until Cloud Functions processed the day.
  final DayResult? server;

  factory AttendanceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    DateTime? time(String k) => (d[k] as Timestamp?)?.toDate();
    return AttendanceRecord(
      uid: d['uid'] as String? ?? '',
      date: d['date'] as String? ?? '',
      events: [
        for (final e in d['events'] as List? ?? const [])
          if (e is Map && eventTypeFromKey(e['type']) != null && e['at'] is Timestamp)
            AttendanceEvent(eventTypeFromKey(e['type'])!, (e['at'] as Timestamp).toDate(), siteId: e['siteId'] as String?),
      ],
      server: d.containsKey('closed')
          ? DayResult(
              checkInAt: time('checkInAt'),
              checkInSource: d['checkInSource'] as String?,
              siteId: d['siteId'] as String?,
              inside: d['inside'] == true,
              lastExitAt: time('lastExitAt'),
              checkOutAt: time('checkOutAt'),
              checkOutType: d['checkOutType'] as String?,
              workedMin: (d['workedMin'] as num?)?.toInt(),
              countedMin: (d['countedMin'] as num?)?.toInt(),
              overtimeMin: (d['overtimeMin'] as num?)?.toInt(),
              // Days stored before the grace period: within it = on time.
              lateMin: switch ((d['lateMin'] as num?)?.toInt()) {
                final m? when m <= lateGraceMin => 0,
                final m => m,
              },
              afterHoursMin: (d['afterHoursMin'] as num?)?.toInt(),
            )
          : null,
    );
  }

  /// The day as it stands now: worked out from the events on the phone (so
  /// a new event shows at once), the same way the server does. [hours]: the
  /// person's schedule ([AppUser.scheduleOr]).
  DayResult result({required WorkHours hours, required bool leavesSite, required bool overtimeAllowed, DateTime? now}) {
    final day = DateTime.parse(date);
    return deriveDay(
      events,
      start: hours.days.contains(day.weekday) ? day.add(Duration(minutes: hours.startMinute)) : null,
      end: day.add(Duration(minutes: hours.endMinute)),
      closeAll: day.add(const Duration(hours: 23, minutes: 55)),
      now: now ?? DateTime.now(),
      leavesSite: leavesSite,
      overtimeAllowed: overtimeAllowed,
    );
  }

  /// The server's result once it has the day (with what older server
  /// results lack filled in here); until then the same rules on the phone.
  DayResult best(AppUser user, WorkHours company) {
    final local = result(
      hours: user.scheduleOr(company),
      leavesSite: user.role.leavesSiteForWork,
      overtimeAllowed: user.overtimeAllowed,
    );
    return server?.fillFrom(local) ?? local;
  }
}

/// The signed-in person's attendance today.
final myAttendanceTodayProvider = StreamProvider<AttendanceRecord?>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(null);
  return attendanceDoc(me.id, attendanceDay(DateTime.now()))
      .snapshots()
      .map((s) => s.exists ? AttendanceRecord.fromDoc(s) : null);
});

/// Everyone's attendance in one month 'yyyy-MM' (monthly report).
final monthAttendanceProvider = StreamProvider.family<List<AttendanceRecord>, String>((ref, month) =>
    FirebaseFirestore.instance
        .collection('attendance')
        .where('month', isEqualTo: month)
        .snapshots()
        .map((s) => [for (final d in s.docs) AttendanceRecord.fromDoc(d)]));

/// Everyone's attendance on one day (HR area, KAM / managers).
final dayAttendanceProvider = StreamProvider.family<Map<String, AttendanceRecord>, String>((ref, day) =>
    FirebaseFirestore.instance.collection('attendance').where('date', isEqualTo: day).snapshots().map((s) => {
          for (final d in s.docs) (d.data()['uid'] as String? ?? ''): AttendanceRecord.fromDoc(d),
        }));

/// Every attendance day of the signed-in person, by date (their calendar;
/// a few hundred small docs a year at most).
final myAttendanceProvider = StreamProvider<Map<String, AttendanceRecord>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return Stream.value(const {});
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('uid', isEqualTo: me.id)
      .snapshots()
      .map((s) => {for (final d in s.docs) (d.data()['date'] as String? ?? ''): AttendanceRecord.fromDoc(d)});
});
