import 'package:firebase_auth/firebase_auth.dart';

import '../features/notifications/push.dart';
import '../features/tracking/tracking_service.dart';

/// Stops live tracking (marking the user offline) and phone pushes before
/// signing out, while the user is still allowed to write their presence.
Future<void> signOut() async {
  await Tracking.stop();
  await unregisterPush();
  await FirebaseAuth.instance.signOut();
}
