// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openAttachmentBytesImpl(
  Uint8List bytes, {
  required String mime,
  required String filename,
}) async {
  try {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    if (mime == 'application/pdf') {
      // The browser's built-in PDF viewer renders in a new tab.
      html.window.open(url, '_blank');
    } else {
      final anchor = html.AnchorElement(href: url)
        ..download = filename
        ..target = '_blank';
      anchor.click();
    }
    return true;
  } catch (_) {
    return false;
  }
}
