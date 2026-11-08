import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who changed a user (2026-11-08): added to every write to `users/{uid}`,
/// so the `userChanged` function can log the writer. The rules accept it
/// only with the writer's own uid and the server time.
Map<String, Object?> userChangeStamp() => {
      'changedBy': FirebaseAuth.instance.currentUser?.uid,
      'changedAt': FieldValue.serverTimestamp(),
    };

/// One change of one field: values as the server stored them (text,
/// numbers, booleans, lists; maps as JSON text, dates as ISO text).
class UserLogChange {
  const UserLogChange(this.field, this.from, this.to);
  final String field;
  final Object? from;
  final Object? to;
}

/// One `user_log` entry (written by the functions, read by GM / SM / HR).
class UserLogEntry {
  const UserLogEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.targetId,
    required this.targetName,
    required this.actorId,
    required this.actorName,
    required this.stamped,
    required this.changes,
  });

  final String id;
  final DateTime? at;

  /// registered | created | approved | rejected | updated | deleted | passwordSet
  final String action;
  final String targetId;
  final String targetName;

  /// Null = unknown (a write from an app build before the log).
  final String? actorId;
  final String actorName;
  final bool stamped;
  final List<UserLogChange> changes;

  factory UserLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return UserLogEntry(
      id: d.id,
      at: (m['at'] as Timestamp?)?.toDate(),
      action: m['action'] as String? ?? 'updated',
      targetId: m['targetId'] as String? ?? '',
      targetName: m['targetName'] as String? ?? '',
      actorId: m['actorId'] as String?,
      actorName: m['actorName'] as String? ?? '',
      stamped: m['stamped'] == true,
      changes: [
        for (final c in (m['changes'] as List?) ?? const [])
          if (c is Map) UserLogChange(c['field'] as String? ?? '', c['from'], c['to']),
      ],
    );
  }
}

/// The latest 500 entries, newest first.
final userLogProvider = StreamProvider<List<UserLogEntry>>((ref) => FirebaseFirestore.instance
    .collection('user_log')
    .orderBy('at', descending: true)
    .limit(500)
    .snapshots()
    .map((s) => s.docs.map(UserLogEntry.fromDoc).toList()));

/// Every entry about one person (no index needed; sorted here).
final userLogForProvider = StreamProvider.family<List<UserLogEntry>, String>((ref, uid) => FirebaseFirestore.instance
    .collection('user_log')
    .where('targetId', isEqualTo: uid)
    .snapshots()
    .map((s) => s.docs.map(UserLogEntry.fromDoc).toList()
      ..sort((a, b) => (b.at ?? DateTime(3000)).compareTo(a.at ?? DateTime(3000)))));
