import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Crash reports (Firebase Crashlytics, 2026-10-27, phones only — no web
/// support). Native crashes are reported by the SDK itself; this sends
/// Flutter framework errors and uncaught Dart errors as non-fatal reports
/// (the app keeps running after them). Off in debug runs. [where] names
/// the isolate in the report ('app', 'trackingService', 'geofence').
/// Call right after Firebase.initializeApp.
Future<void> setUpCrashReports(String where) async {
  if (kIsWeb) return;
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  await crashlytics.setCustomKey('isolate', where);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    crashlytics.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack);
    return true;
  };
}

/// Reports carry the signed-in user's id and role (to find a person's
/// crashes); cleared on sign-out.
final crashReportUserProvider = Provider<void>((ref) {
  if (kIsWeb) return;
  final me = ref.watch(currentUserProvider).value;
  final crashlytics = FirebaseCrashlytics.instance;
  crashlytics.setUserIdentifier(me?.id ?? '').ignore();
  crashlytics.setCustomKey('role', me?.role.value ?? '').ignore();
});
