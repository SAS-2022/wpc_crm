import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

/// One phone per person shares the location (user request 2026-10-18, after
/// a manager opened a sales exec's account on another phone in another city
/// and both phones' positions mixed into one route). RTDB
/// `tracking_device/{uid}` = {id, platform, since}: the phone with that id
/// tracks; any other phone signed in to the account stays silent until the
/// user taps "Use this phone" on it.

const _prefsKey = 'trackingDeviceId';

/// This install's id (random, kept in the app's storage; a reinstall gets a
/// new one). Also read in the Android service isolate.
Future<String> localDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // the other isolate may have written it
  final existing = prefs.getString(_prefsKey);
  if (existing != null) return existing;
  final rnd = Random.secure();
  final id = List.generate(12, (_) => rnd.nextInt(16).toRadixString(16)).join();
  await prefs.setString(_prefsKey, id);
  return id;
}

DatabaseReference trackingDeviceRef(String uid) => FirebaseDatabase.instance.ref('tracking_device/$uid');

/// Makes this phone the one that shares [uid]'s location.
Future<void> claimTracking(String uid, String deviceId) => trackingDeviceRef(uid).set({
      'id': deviceId,
      'platform': defaultTargetPlatform.name,
      'since': ServerValue.timestamp,
    });

/// For tracked staff on a phone: false when another phone shares their
/// location (Home then offers "Use this phone"); null when not applicable
/// or not known yet. No owner yet counts as this phone (the tracker claims).
final thisPhoneTracksProvider = StreamProvider<bool?>((ref) async* {
  final me = ref.watch(currentUserProvider).value;
  if (kIsWeb || me == null || !me.active || !me.role.isTracked) {
    yield null;
    return;
  }
  final id = await localDeviceId();
  yield* trackingDeviceRef(me.id).onValue.map((e) {
    final owner = (e.snapshot.value as Map?)?['id'];
    return owner == null || owner == id;
  });
});
