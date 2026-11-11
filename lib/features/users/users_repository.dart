import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../firebase_options.dart';
import '../../core/saving.dart';
import 'user_log.dart';

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
  if (me == null || !me.can.isAdmin) return;
  final users = ref.watch(usersProvider).value;
  if (users == null || users.isEmpty) return;
  FirebaseDatabase.instance
      .ref('roles')
      // Unknown roles (from a newer app version) are left as they are.
      .update({for (final u in users) if (u.role != UserRole.unknown) u.id: u.role.value})
      .catchError((Object e) => debugPrint('Role mirror failed: $e'));
  // Extra roles (2026-11-11): RTDB `role_extras/{uid}` {role: true}.
  FirebaseDatabase.instance
      .ref('role_extras')
      .set({for (final u in users) if (u.extraRoles.isNotEmpty) u.id: _extrasMap(u)})
      .catchError((Object e) => debugPrint('Extra roles mirror failed: $e'));
});

Map<String, bool> _extrasMap(AppUser u) => {for (final r in u.extraRoles) r.value: true};

class UsersRepository {
  final _users = FirebaseFirestore.instance.collection('users');

  /// Creates the Auth account through a secondary Firebase app so the
  /// signed-in manager is not signed out.
  /// Returns how many unassigned clients were given to the new user.
  Future<int> create(AppUser user, String password) => saving(() async {
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
  });

  /// Returns how many unassigned clients were given to the user.
  Future<int> update(AppUser user) => saving(() => _save(user.id, user));

  /// The drivers and workers warehouse supervisor [supervisorId] follows
  /// (2026-11-04, from their user form): sets `supervisorId` on the people
  /// added, clears it on the people removed. [current]: everyone now under them.
  /// Overtime on / off for [uid] and its daily cap (null = standard 3 h);
  /// department heads use it from Attendance → Overtime permission
  /// (2026-11-05; the rules allow only these two fields for them).
  Future<void> setOvertime(String uid, {required bool allowed, int? maxMin}) => saving(() => _users.doc(uid).update({
        'overtimeAllowed': allowed,
        'overtimeMaxMin': allowed ? maxMin : null,
        ...userChangeStamp(),
      }));

  Future<void> setSupervised(String supervisorId, Set<String> ids, Iterable<AppUser> current, List<AppUser> users) =>
      saving(() async {
        final before = {for (final u in current) u.id};
        final batch = FirebaseFirestore.instance.batch();
        final changed = <AppUser, String?>{};
        for (final u in users) {
          final to = ids.contains(u.id) ? supervisorId : (before.contains(u.id) ? null : u.supervisorId);
          if (to == u.supervisorId) continue;
          batch.update(_users.doc(u.id), {'supervisorId': to, ...userChangeStamp()});
          changed[u] = to;
        }
        if (changed.isEmpty) return;
        await batch.commit();
        // Drivers: the RTDB copy their tracking rules read.
        for (final MapEntry(key: u, value: to) in changed.entries) {
          if (u.role == UserRole.driver) await FirebaseDatabase.instance.ref('driver_supervisors/${u.id}').set(to);
        }
      });

  /// A self-registered account: approved with the role and details chosen on
  /// the form (it becomes active), or turned down.
  Future<int> approveRegistration(AppUser user) => saving(() async {
        final assigned = await _save(user.id, user);
        await _users.doc(user.id).update({'approval': '', 'active': true, ...userChangeStamp()});
        return assigned;
      });

  /// A driver sets their own home location (2026-10-27); the rules allow it
  /// only while none is set — after that the user form changes it.
  Future<void> setOwnHomeLocation(String uid, double lat, double lng) =>
      saving(() => _users.doc(uid).update({'homeLocation': {'lat': lat, 'lng': lng}, ...userChangeStamp()}));

  /// The person's own side menu order (web); null = back to the default.
  Future<void> setMenuOrder(String uid, List<String>? order) =>
      saving(() => _users.doc(uid).update({'menuOrder': order}));

  /// The person's own bottom tabs (null = default; More → Bottom tabs).
  Future<void> setBottomTabs(String uid, List<String>? tabs) =>
      saving(() => _users.doc(uid).update({'bottomTabs': tabs}));

  Future<void> rejectRegistration(String uid) =>
      saving(() => _users.doc(uid).update({'approval': 'rejected', 'active': false, ...userChangeStamp()}));

  /// Deletes the user for good with the `deleteUser` Cloud Function: their
  /// login account (so the email can be used again), profile, role, push
  /// tokens and location data; their clients become unassigned and their
  /// sales team loses its KAM. Visits, plans, attendance and leave stay as
  /// history. Only the accounts in [userDeleterEmails].
  Future<void> delete(String uid) => saving(() async {
    await FirebaseFunctions.instance.httpsCallable('deleteUser').call<Object?>({'uid': uid});
  });

  /// Sets someone's password with the `setUserPassword` Cloud Function,
  /// e.g. for username accounts, which can't get a reset email. GM: anyone;
  /// sales manager: not GMs or sales managers; logistics manager: drivers.
  Future<void> setPassword(String uid, String password) => saving(() async {
    await FirebaseFunctions.instance
        .httpsCallable('setUserPassword')
        .call<Object?>({'uid': uid, 'password': password});
  });

  // RTDB keeps a copy of the role because its rules cannot read Firestore.
  Future<int> _save(String uid, AppUser user) async {
    // Merged: keeps what the app writes itself (app versions, reminders).
    await _users.doc(uid).set({...user.toMap(), ...userChangeStamp()}, SetOptions(merge: true));
    await FirebaseDatabase.instance.ref('roles/$uid').set(user.role.value);
    // Extra roles for the RTDB rules. Only the sales manager / GM may write it
    // (and change extra roles): others' saves leave it as it is.
    await FirebaseDatabase.instance
        .ref('role_extras/$uid')
        .set(user.extraRoles.isEmpty ? null : _extrasMap(user))
        .catchError((Object e) => debugPrint('Extra roles not saved: $e'));
    // A driver's warehouse supervisor reads their tracking: RTDB rules use this copy.
    await FirebaseDatabase.instance
        .ref('driver_supervisors/$uid')
        .set(user.role == UserRole.driver ? user.supervisorId : null);
    // Workers keep `supervisorId` only in Firestore; `location_viewers` is
    // rebuilt by the `syncLocationViewers` function on every users write.
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
