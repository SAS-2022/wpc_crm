import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_user.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Profile of the signed-in user from `users/{uid}`; null when signed out or missing.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);
});

/// Selected app language; null follows the device language.
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    if (code != null) state = Locale(code);
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await (await SharedPreferences.getInstance())
        .setString(_key, locale.languageCode);
  }
}
