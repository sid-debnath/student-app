import 'dart:io';
import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

Future<bool> openAttachmentBytesImpl(
  Uint8List bytes, {
  required String mime,
  required String filename,
}) async {
  try {
    final dir = await Directory.systemTemp.createTemp('homework_attachment_');
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
