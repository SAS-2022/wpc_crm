import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../attachments/attachments.dart';
import 'ocr/ocr_stub.dart' if (dart.library.io) 'ocr/ocr_mobile.dart' as ocr;

export 'ocr/ocr_stub.dart' if (dart.library.io) 'ocr/ocr_mobile.dart' show canReadPhotos;

/// The text of a picked document, read on the device (no paid service):
/// a PDF's text layer (all platforms); a scanned PDF's first page or a photo
/// through ML Kit on phones. Null when nothing could be read (e.g. a photo
/// on the web). [pages]: text-layer pages read; [scannedPages]: pages of a
/// scanned PDF recognized as pictures (phones only).
Future<String?> readDocumentText(PendingFile file, {int pages = 3, int scannedPages = 1}) async {
  if (file.contentType == 'application/pdf') {
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(file.bytes, sourceName: 'doc_${identityHashCode(file)}');
    try {
      final text = StringBuffer();
      for (final page in doc.pages.take(pages)) {
        text.writeln((await page.loadStructuredText()).fullText);
      }
      if (text.toString().trim().length >= 20) return text.toString();
      // Scanned PDF (no text layer): recognize the first page(s) as pictures.
      if (doc.pages.isEmpty || !ocr.canReadPhotos) return null;
      final scanned = StringBuffer();
      for (final page in doc.pages.take(scannedPages)) {
        final scale = 2000 / (page.width > page.height ? page.width : page.height);
        final image = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xffffffff,
        );
        if (image == null) continue;
        try {
          final png = img.encodePng(img.Image.fromBytes(
            width: image.width,
            height: image.height,
            bytes: image.pixels.buffer,
            order: img.ChannelOrder.bgra,
            numChannels: 4,
          ));
          scanned.writeln(await ocr.recognizeImageText(png, 'png') ?? '');
        } finally {
          image.dispose();
        }
      }
      return scanned.toString().trim().isEmpty ? null : scanned.toString();
    } finally {
      await doc.dispose();
    }
  }
  if (file.contentType.startsWith('image/')) {
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    return ocr.recognizeImageText(file.bytes, ext);
  }
  return null;
}

/// Logged when reading fails, so a bad file never blocks the upload.
Future<String?> tryReadDocumentText(PendingFile file, {int pages = 3, int scannedPages = 1}) async {
  try {
    return await readDocumentText(file, pages: pages, scannedPages: scannedPages);
  } catch (e) {
    debugPrint('readDocumentText: $e');
    return null;
  }
}
