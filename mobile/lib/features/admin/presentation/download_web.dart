import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands the browser a file to save, without a round trip to the server.
bool saveTextFile(String name, String text, String mimeType) {
  // A byte order mark tells Excel the file is UTF-8, so Nepali names survive.
  final bytes = utf8.encode('\uFEFF$text');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
