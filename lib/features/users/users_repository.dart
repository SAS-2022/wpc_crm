import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../firebase_options.dart';

final usersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());
});

/// The email belongs to an existing account that can't be reused.
class EmailInUseException implements Exception {
  const EmailInUseException();
}

final usersRepositoryProvider = Provider((ref) => UsersRepository());

/// While a GM / sales manager is signed in, copies every user's role to RTDB
/// `roles/{uid}` whenever the user list changes. RTDB rules rely on that copy;
/// a missing one (e.g. a role changed in the console) blocked a KAM's live map.
final roleMirrorProvider = Provider<void>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null || !me.role.isAdmin) return;
  final users = ref.watch(usersProvider).value;
  if (users == null || users.isEmpty) return;
  FirebaseDatabase.instance
      .ref('roles')
      .update({for (final u in users) u.id: u.role.value})
      .catchError((Object e) => debugPrint('Role mirror failed: $e'));
});

class UsersRepository {
  final _users = FirebaseFirestore.instance.collection('users');

  /// Creates the Auth account through a secondary Firebase app so the
  /// signed-in manager is not signed out.
  /// Returns how many unassigned clients were given to the new user.
  Future<int> create(AppUser user, String password) async {
    const appName = 'user-creator';
    final app = Firebase.apps.any((a) => a.name == appName)
        ? Firebase.app(appName)
        : await Firebase.initializeApp(
            name: appName,
            options: DefaultFirebaseOptions.currentPlatform,
          );
    final auth = FirebaseAuth.instanceFor(app: app);
    UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(email: user.email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      // An earlier attempt may have created the account but failed to save
      // the profile. With the same password, finish that attempt.
      try {
        cred = await auth.signInWithEmailAndPassword(email: user.email, password: password);
      } on FirebaseAuthException {
        throw const EmailInUseException();
      }
    }
    final uid = cred.user!.uid;
    await auth.signOut();
    return _save(uid, user);
  }

  /// Returns how many unassigned clients were given to the user.
  Future<int> update(AppUser user) => _save(user.id, user);

  /// Removes the user's profile and role, which ends all their access, and
  /// unassigns their clients and sales team. Their visits stay as history.
  /// The login account itself can only be removed in Firebase Console →
  /// Authentication (client apps can't delete other users' accounts).
  Future<void> delete(String uid) async {
    final db = FirebaseFirestore.instance;
    final clients = await db.collection('clients').where('assignedTo', isEqualTo: uid).get();
    final team = await _users.where('kamId', isEqualTo: uid).get();
    final refs = [
      for (final d in clients.docs) (d.reference, {'assignedTo': null}),
      for (final d in team.docs) (d.reference, {'kamId': null}),
    ];
    for (var i = 0; i < refs.length; i += 400) {
      final batch = db.batch();
      for (final (ref, data) in refs.skip(i).take(400)) {
        batch.update(ref, data);
      }
      await batch.commit();
    }
    await FirebaseDatabase.instance.ref('roles/$uid').remove();
    await _users.doc(uid).delete();
  }

  // RTDB keeps a copy of the role because its rules cannot read Firestore.
  Future<int> _save(String uid, AppUser user) async {
    await _users.doc(uid).set(user.toMap());
    await FirebaseDatabase.instance.ref('roles/$uid').set(user.role.value);
    return user.role.isTracked && user.active && user.odooName.isNotEmpty
        ? _assignOdooClients(uid, user.odooName)
        : 0;
  }

  /// Gives a sales executive or KAM the unassigned clients that Odoo lists under their
  /// salesperson name. Clients already assigned to someone are left alone.
  Future<int> _assignOdooClients(String uid, String odooName) async {
    final db = FirebaseFirestore.instance;
    final clients = await db
        .collection('clients')
        .where('odooSalesperson', isEqualTo: odooName.trim())
        .where('assignedTo', isNull: true)
        .get();
    // Hidden clients stay unassigned.
    final docs = clients.docs.where((d) => d.data()['hidden'] != true).toList();
    for (var i = 0; i < docs.length; i += 400) {
      final batch = db.batch();
      for (final d in docs.skip(i).take(400)) {
        batch.update(d.reference, {'assignedTo': uid, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
    return docs.length;
  }
}
