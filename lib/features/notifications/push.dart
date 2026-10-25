import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../attendance/site_check.dart';
import '../tracking/wake_ping.dart';

/// Phones only; the web dashboard uses the in-app list.
bool get _supported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

DocumentReference<Map<String, dynamic>> _device(String uid, String token) =>
    FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(token);

/// Registers this phone for push while a user is signed in. The `sendPush`
/// Cloud Function sends each new `notifications` doc to the user's devices,
/// in the language saved here. Tapping a push opens the notifications list.
final pushProvider = Provider<void>((ref) {
  if (!_supported) return;
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return;
  final lang = ref.watch(localeProvider)?.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
  final messaging = FirebaseMessaging.instance;

  Future<void> save(String token) => _device(uid, token).set({
        'platform': defaultTargetPlatform.name,
        'lang': lang == 'ar' ? 'ar' : 'en',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  void open(RemoteMessage message) =>
      ref.read(routerProvider).go(message.data['route'] as String? ?? '/notifications');

  final subs = <StreamSubscription<dynamic>>[
    messaging.onTokenRefresh.listen((t) => save(t).ignore()),
    FirebaseMessaging.onMessageOpenedApp.listen(open),
    // Wake ping while the app is open (Android may have stopped the service);
    // attendance site check (site_check.dart).
    FirebaseMessaging.onMessage.listen((m) {
      if (m.data['type'] == 'wake') answerWakePing().ignore();
      if (m.data['type'] == 'siteCheck') answerSiteCheck().ignore();
    }),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });

  () async {
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await save(token);
      final initial = await messaging.getInitialMessage();
      if (initial != null) open(initial);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }();
});

/// Stops pushes to this phone for the signed-in user (call before sign-out).
Future<void> unregisterPush() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (!_supported || uid == null) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _device(uid, token).delete();
  } catch (_) {
    // Sign-out must not fail on this; a stale token is cleaned up by sendPush.
  }
}
