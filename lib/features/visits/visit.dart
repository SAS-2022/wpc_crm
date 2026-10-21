import 'package:cloud_firestore/cloud_firestore.dart';

import '../clients/given_items.dart';

/// Check-ins farther than this from the client are flagged. 300 m unless
/// changed in App settings (`AppSettings.apply`).
var visitRadiusMeters = 300.0;

/// `visits.type`: a visit at the client, or a phone call that counts like one
/// (turns the client green, ticks the plan item) but is shown apart.
enum VisitType { visit, call }

/// "4 min" / "45 s": the length of a call made from the app.
String formatCallDuration(int seconds) =>
    seconds < 60 ? '$seconds s' : '${(seconds / 60).round()} min';

String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

class Visit {
  const Visit({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.salesExecId,
    required this.checkedInAt,
    required this.notes,
    required this.distanceMeters,
    required this.accuracy,
    required this.mocked,
    this.kamId,
    this.kamMarkedAt,
    this.checkInLat,
    this.checkInLng,
    this.type = VisitType.visit,
    this.callFromApp = false,
    this.callSeconds,
    this.locationTypeId = '',
    this.given = const {},
  });

  final String id;
  final String clientId;
  final String clientName;

  /// The user who made the visit (a sales executive or a KAM visiting alone).
  final String salesExecId;
  final DateTime? checkedInAt;
  final String notes;

  /// Distance between the check-in position and the client; null when the
  /// client had no location.
  final double? distanceMeters;

  /// GPS accuracy of the check-in in meters.
  final double? accuracy;

  /// True when Android reported the position as coming from a mock-location app.
  final bool mocked;

  /// KAM who marked that they were at this visit, and when they marked it.
  final String? kamId;
  final DateTime? kamMarkedAt;

  /// Where the phone was at check-in.
  final double? checkInLat;
  final double? checkInLng;

  /// A visit at the client, or a phone call (no position, never flagged).
  final VisitType type;

  /// The call was dialled from the app; [callSeconds] is then the time the
  /// user was away from the app (dialling, ringing and talking).
  final bool callFromApp;
  final int? callSeconds;

  /// Label of the client location the visit was at (`settings/locationTypes`
  /// id), e.g. 'factory'; empty for calls, unlabelled or older visits.
  final String locationTypeId;

  /// Catalogs / display stands handed over at this visit.
  final Map<GivenItem, int> given;

  bool get isCall => type == VisitType.call;

  /// Far from the client or fake GPS. Calls have no position, so never.
  bool get isFlagged =>
      !isCall && (mocked || (distanceMeters != null && distanceMeters! > visitRadiusMeters));

  factory Visit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Visit(
      id: doc.id,
      clientId: d['clientId'] as String? ?? '',
      clientName: d['clientName'] as String? ?? '',
      salesExecId: d['salesExecId'] as String? ?? '',
      checkedInAt: (d['checkedInAt'] as Timestamp?)?.toDate(),
      notes: d['notes'] as String? ?? '',
      distanceMeters: (d['distanceMeters'] as num?)?.toDouble(),
      accuracy: (d['accuracy'] as num?)?.toDouble(),
      mocked: d['mocked'] as bool? ?? false,
      kamId: d['kamId'] as String?,
      kamMarkedAt: (d['kamMarkedAt'] as Timestamp?)?.toDate(),
      checkInLat: (d['checkInLat'] as num?)?.toDouble(),
      checkInLng: (d['checkInLng'] as num?)?.toDouble(),
      // Visits saved before calls existed have no type.
      type: d['type'] == 'call' ? VisitType.call : VisitType.visit,
      callFromApp: d['callFromApp'] as bool? ?? false,
      callSeconds: (d['callSeconds'] as num?)?.toInt(),
      locationTypeId: d['locationTypeId'] as String? ?? '',
      given: parseGiven(d['given']),
    );
  }
}

/// One visit per client per day (user decision 2026-10-19): [userId]'s visit
/// (not call) to the client of [visits] on [day]'s date, if any. A visit
/// still waiting for its server time counts as now.
Visit? sameDayVisit(Iterable<Visit> visits, String userId, DateTime day, {DateTime? now}) {
  for (final v in visits) {
    if (v.isCall || v.salesExecId != userId) continue;
    final at = v.checkedInAt ?? now ?? DateTime.now();
    if (at.year == day.year && at.month == day.month && at.day == day.day) return v;
  }
  return null;
}

class VisitComment {
  const VisitComment({required this.id, required this.authorId, required this.body, required this.createdAt});

  final String id;
  final String authorId;
  final String body;
  final DateTime? createdAt;

  factory VisitComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return VisitComment(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      body: d['body'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
