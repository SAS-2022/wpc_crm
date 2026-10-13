import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }
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
