import 'dart:typed_data';

import 'open_attachment_stub.dart'
    if (dart.library.html) 'open_attachment_web.dart'
    if (dart.library.io) 'open_attachment_io.dart';

/// Opens [bytes] with the platform's native handler.
///
/// - Web: previews PDFs in a new tab and downloads other file types.
/// - Desktop/mobile: writes a temporary file and hands it to the OS.
///
/// Returns `false` when the platform cannot handle the file.
Future<bool> openAttachmentBytes(
  Uint8List bytes, {
  required String mime,
  required String filename,
}) {
  return openAttachmentBytesImpl(bytes, mime: mime, filename: filename);
}
