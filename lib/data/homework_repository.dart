import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../models/homework.dart';
import '../models/homework_file.dart';
import 'paths.dart';

class HomeworkAttachment {
  const HomeworkAttachment({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class HomeworkRepository {
  HomeworkRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  static const _maxDocumentBytes = 700 * 1024; // keep base64 under the 1 MiB doc cap

  Stream<List<Homework>> watch({String? classId}) {
    Query<Map<String, dynamic>> query = _paths.homework;
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map((snap) {
      final items = snap.docs.map((doc) => Homework.fromMap(doc.id, doc.data())).toList();
      items.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return items;
    });
  }

  Stream<List<HomeworkFile>> watchFiles(String homeworkId) {
    return _paths.homeworkFiles(homeworkId).snapshots().map((snap) {
      return snap.docs.map((doc) => HomeworkFile.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<List<String>> upsert(
    Homework homework, {
    List<HomeworkAttachment> files = const [],
  }) async {
    final id = homework.id.isEmpty ? _uuid.v4() : homework.id;
    await _paths.homework.doc(id).set(
      Homework(
        id: id,
        classId: homework.classId,
        subject: homework.subject,
        title: homework.title,
        body: homework.body,
        dueDate: homework.dueDate,
        attachmentUrls: homework.attachmentUrls,
        createdBy: homework.createdBy,
      ).toMap(),
      SetOptions(merge: true),
    );

    final skipped = <String>[];
    for (final file in files) {
      final saved = await _saveFile(homeworkId: id, file: file);
      if (!saved) skipped.add(file.fileName);
    }
    return skipped;
  }

  Future<bool> _saveFile({
    required String homeworkId,
    required HomeworkAttachment file,
  }) async {
    final fileId = _uuid.v4();
    final mime = _contentType(file.fileName);

    if (_isVideo(file.fileName)) {
      return _saveToStorage(homeworkId, fileId, file, mime, kind: 'video');
    }

    if (_isImage(file.fileName)) {
      final jpeg = _compressImage(file.bytes);
      if (jpeg == null) return false;
      try {
        await _paths.homeworkFiles(homeworkId).doc(fileId).set({
          'name': file.fileName,
          'kind': 'image',
          'mime': 'image/jpeg',
          'data': base64Encode(jpeg),
        });
        return true;
      } catch (_) {
        return false;
      }
    }

    // Documents (PDF, Word, Excel, …) and any other file type. Small files are
    // stored inline as base64 (Spark-safe); larger ones go to Storage on Blaze.
    if (file.bytes.lengthInBytes <= _maxDocumentBytes) {
      try {
        await _paths.homeworkFiles(homeworkId).doc(fileId).set({
          'name': file.fileName,
          'kind': 'document',
          'mime': mime,
          'data': base64Encode(file.bytes),
        });
        return true;
      } catch (_) {
        return false;
      }
    }

    return _saveToStorage(homeworkId, fileId, file, mime, kind: 'document');
  }

  Future<bool> _saveToStorage(
    String homeworkId,
    String fileId,
    HomeworkAttachment file,
    String mime, {
    required String kind,
  }) async {
    if (!AppConfig.useStorage) return false;
    try {
      final ref = FirebaseStorage.instance.ref(
        'institutions/$institutionId/homework/$homeworkId/${file.fileName}',
      );
      await ref.putData(file.bytes, SettableMetadata(contentType: mime));
      final url = await ref.getDownloadURL();
      await _paths.homeworkFiles(homeworkId).doc(fileId).set({
        'name': file.fileName,
        'kind': kind,
        'mime': mime,
        'url': url,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Uint8List? _compressImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (bytes.lengthInBytes <= 120000) return bytes;
        return null;
      }
      var work = decoded;
      if (work.width > 800) {
        work = img.copyResize(work, width: 800);
      }
      var encoded = Uint8List.fromList(img.encodeJpg(work, quality: 50));
      if (encoded.lengthInBytes > 120000) {
        work = img.copyResize(work, width: 480);
        encoded = Uint8List.fromList(img.encodeJpg(work, quality: 40));
      }
      if (encoded.lengthInBytes > 200000) return null;
      return encoded;
    } catch (_) {
      return bytes.lengthInBytes <= 120000 ? bytes : null;
    }
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'application/octet-stream';
  }

  bool _isImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  bool _isVideo(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  Future<void> deleteFile(String homeworkId, String fileId) {
    return _paths.homeworkFiles(homeworkId).doc(fileId).delete();
  }

  Future<void> delete(String id) async {
    final files = await _paths.homeworkFiles(id).get();
    for (final doc in files.docs) {
      await doc.reference.delete();
    }
    await _paths.homework.doc(id).delete();
  }
}
