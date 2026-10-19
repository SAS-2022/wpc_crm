import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Phones: ML Kit on-device text recognition (free, offline). Latin script
/// only, which covers the numbers and the English half of Saudi documents.
bool get canReadPhotos => Platform.isAndroid || Platform.isIOS;

Future<String?> recognizeImageText(Uint8List bytes, String extension) async {
  if (!canReadPhotos) return null;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/doc_${DateTime.now().microsecondsSinceEpoch}.$extension');
  await file.writeAsBytes(bytes);
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
    return result.text;
  } finally {
    await recognizer.close();
    try {
      await file.delete();
    } catch (_) {}
  }
}
