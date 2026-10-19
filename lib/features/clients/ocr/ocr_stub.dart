import 'dart:typed_data';

/// Web: no on-device text recognition for photos (PDFs are still read).
const canReadPhotos = false;

Future<String?> recognizeImageText(Uint8List bytes, String extension) async => null;
