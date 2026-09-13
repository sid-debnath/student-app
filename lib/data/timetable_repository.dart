import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/timetable_period.dart';
import '../models/timetable_photo.dart';
import 'paths.dart';

class TimetableRepository {
  TimetableRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<TimetablePeriod>> watch(String classId) {
    return _paths.periods(classId).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => TimetablePeriod.fromMap(doc.id, {...doc.data(), 'classId': classId}))
          .toList();
      items.sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        return day != 0 ? day : a.start.compareTo(b.start);
      });
      return items;
    });
  }

  Future<void> upsert(TimetablePeriod period) async {
    final id = period.id.isEmpty ? _uuid.v4() : period.id;
    await _paths.periods(period.classId).doc(id).set(period.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String classId, String periodId) {
    return _paths.periods(classId).doc(periodId).delete();
  }

  Stream<List<TimetablePhoto>> watchPhotos(String classId, String periodId) {
    return _paths.periodPhotos(classId, periodId).snapshots().map((snap) {
      return snap.docs
          .map((doc) => TimetablePhoto.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Compresses [bytes] to a small JPEG and stores it base64-encoded in
  /// Firestore (no Storage bucket required on Spark). Returns false when the
  /// image is too large or could not be processed.
  Future<bool> savePhoto({
    required String classId,
    required String periodId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final jpeg = _compressImage(bytes);
    if (jpeg == null) return false;
    final id = _uuid.v4();
    await _paths.periodPhotos(classId, periodId).doc(id).set({
      'name': fileName,
      'mime': 'image/jpeg',
      'data': base64Encode(jpeg),
    });
    return true;
  }

  Future<void> deletePhoto(String classId, String periodId, String photoId) {
    return _paths.periodPhotos(classId, periodId).doc(photoId).delete();
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
}
