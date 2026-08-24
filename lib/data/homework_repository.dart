import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

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
    if (_isVideo(file.fileName)) {
      try {
        final ref = FirebaseStorage.instance.ref(
          'institutions/$institutionId/homework/$homeworkId/${file.fileName}',
        );
        await ref.putData(file.bytes, SettableMetadata(contentType: _contentType(file.fileName)));
        final url = await ref.getDownloadURL();
        await _paths.homeworkFiles(homeworkId).doc(fileId).set({
          'name': file.fileName,
          'kind': 'video',
          'mime': _contentType(file.fileName),
          'url': url,
        });
        return true;
      } catch (_) {
        return false;
      }
    }

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
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'image/jpeg';
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
