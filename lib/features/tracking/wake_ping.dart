import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import '../attendance/site_check.dart';
import 'tracking_device.dart';
import 'tracking_service.dart';

// Wake-up pings (user request 2026-10-24): when a phone that should share its
// location goes quiet for 10 minutes, the `offlineAlerts` Cloud Function sends
// it a silent push ({type: 'wake'}, nothing shown). The app answers in
// `presence/{uid}.wokenAt`, so the server knows the phone is alive, and
// restarts tracking if Android stopped the service. No answer → the person's
// managers are told (functions/wakePing.js).

/// Background push handler (registered in main.dart). Runs in its own
/// isolate, also when the app was closed (not after a force-stop). Also
/// answers attendance site checks (site_check.dart).
@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {
  final type = message.data['type'];
  if (type != 'wake' && type != 'siteCheck') return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await (type == 'wake' ? answerWakePing() : answerSiteCheck());
}

/// Answers a wake ping from the phone that shares the location.
Future<void> answerWakePing() async {
  final user = FirebaseAuth.instance.currentUser ?? await FirebaseAuth.instance.authStateChanges().first;
  if (user == null) return;
  final owner = (await trackingDeviceRef(user.uid).get()).value;
  if (owner is! Map || owner['id'] != await localDeviceId()) return;
  await FirebaseDatabase.instance.ref('presence/${user.uid}').update({'wokenAt': ServerValue.timestamp});
  await Tracking.wake(user.uid);
}
