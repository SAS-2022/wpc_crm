import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// iOS plays a push's custom sound only from the app bundle or the app's
/// Library/Sounds folder: the overtime alert (2026-10-25, own sound; the
/// server sends `sound: overtime_alert.caf`) is copied there from the
/// assets. Android has it as res/raw/overtime_alert (MainActivity.kt channel).
Future<void> installNotificationSounds() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    final dir = Directory('${(await getLibraryDirectory()).path}/Sounds');
    final file = File('${dir.path}/overtime_alert.caf');
    if (await file.exists()) return;
    await dir.create(recursive: true);
    final data = await rootBundle.load('assets/sounds/overtime_alert.caf');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  } catch (e) {
    debugPrint('notification sounds: $e');
  }
}
