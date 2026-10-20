import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report.dart';
import 'routing_pace.dart';

/// An entry of `import_batches`, written by each client import.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.importedBy,
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.withoutLocation,
    required this.createdAt,
  });

  final String id;
  final String fileName;
  final String importedBy;
  final int added;
  final int updated;
  final int unchanged;
  final int withoutLocation;
  final DateTime? createdAt;

  factory ImportBatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    int n(String key) => (d[key] as num?)?.toInt() ?? 0;
    return ImportBatch(
      id: doc.id,
      fileName: d['fileName'] as String? ?? '',
      importedBy: d['importedBy'] as String? ?? '',
      added: n('added'),
      updated: n('updated'),
      unchanged: n('unchanged'),
      withoutLocation: n('withoutLocation'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Latest imports; readable by sales manager and GM only.
final importBatchesProvider = StreamProvider.autoDispose<List<ImportBatch>>((ref) => FirebaseFirestore.instance
    .collection('import_batches')
    .orderBy('createdAt', descending: true)
    .limit(20)
    .snapshots()
    .map((s) => s.docs.map(ImportBatch.fromDoc).toList()));

/// Route points of one person on one day ('yyyy-MM-dd'), live while open.
final routePointsProvider = StreamProvider.autoDispose.family<List<RoutePoint>, (String, String)>((ref, key) =>
    FirebaseDatabase.instance.ref('location_history/${key.$1}/${key.$2}').onValue.map((event) => [
          if (event.snapshot.value case final Map<Object?, Object?> points)
            for (final p in points.values) ?_point(p),
        ]));

RoutePoint? _point(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  final (lat, lng, t) = (value['lat'], value['lng'], value['t']);
  if (lat is! num || lng is! num || t is! num) return null;
  return RoutePoint(
    lat: lat.toDouble(),
    lng: lng.toDouble(),
    t: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
    accuracy: (value['accuracy'] as num?)?.toDouble(),
    mocked: value['mocked'] == true,
  );
}

/// Road-snapped legs of one person's day ('yyyy-MM-dd'), written by the
/// `snapRoute` Cloud Function.
final snappedRouteProvider = StreamProvider.autoDispose.family<SnappedRoute, (String, String)>((ref, key) =>
    FirebaseDatabase.instance.ref('route_snapped/${key.$1}/${key.$2}').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map<Object?, Object?>) return const SnappedRoute();
      return SnappedRoute(
        handled: (value['n'] as num?)?.toInt() ?? 0,
        legs: [
          if (value['legs'] case final Map<Object?, Object?> legs)
            for (final MapEntry(:key, :value) in legs.entries) ?_leg(key, value),
        ],
      );
    }));

SnappedLeg? _leg(Object? key, Object? value) {
  final times = '$key'.split('_').map(int.tryParse).toList();
  if (times.length != 2 || times.contains(null) || value is! Map<Object?, Object?>) return null;
  final encoded = value['p'];
  return SnappedLeg(
    from: DateTime.fromMillisecondsSinceEpoch(times[0]!),
    to: DateTime.fromMillisecondsSinceEpoch(times[1]!),
    meters: (value['m'] as num?)?.toDouble() ?? 0,
    points: encoded is String ? decodePolyline(encoded) : null,
  );
}

/// Asks `snapRoute` to snap whatever of the day isn't snapped yet. Throws
/// [FirebaseFunctionsException] e.g. when the Routes API isn't enabled.
Future<void> snapRoute(String uid, String day) =>
    FirebaseFunctions.instance.httpsCallable('snapRoute').call({'uid': uid, 'day': day});

/// Day timelines of every salesperson in the given months ('yyyy-MM',
/// comma-separated), by `uid_yyyy-MM-dd`. Built nightly by the
/// `buildTimelines` Cloud Function.
final dayTimelinesProvider = StreamProvider.autoDispose.family<Map<String, DayTimeline>, String>((ref, months) {
  final list = months.split(',').where((m) => m.isNotEmpty).toList();
  if (list.isEmpty) return Stream.value(const {});
  return FirebaseFirestore.instance
      .collection('day_timelines')
      .where('month', whereIn: list.take(10).toList())
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: DayTimeline.fromMap(d.data())});
});

/// One person's day timeline ('uid', 'yyyy-MM-dd').
final dayTimelineProvider = StreamProvider.autoDispose.family<DayTimeline?, (String, String)>((ref, key) =>
    FirebaseFirestore.instance
        .doc('day_timelines/${key.$1}_${key.$2}')
        .snapshots()
        .map((s) => s.exists ? DayTimeline.fromMap(s.data()!) : null));

/// Asks `buildTimeline` to (re)build one day now, e.g. today's so far.
Future<void> buildTimelineNow(String uid, String day) =>
    FirebaseFunctions.instance.httpsCallable('buildTimeline').call({'uid': uid, 'day': day});
