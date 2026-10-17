import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Starts a browser download of [bytes] as [fileName].
void saveBytes(List<int> bytes, String fileName, String mimeType) {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(link);
  link.click();
  link.remove();
  // Revoking right away can cancel the download in some browsers.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
