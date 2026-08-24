import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/announcement.dart';
import 'paths.dart';

class AnnouncementRepository {
  AnnouncementRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  static const _maxEmbeddedBytes = 700000;

  Stream<List<Announcement>> watch() {
    return _paths.announcements.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => Announcement.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Future<void> save(
    Announcement announcement, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final isNew = announcement.id.isEmpty;
    final id = isNew ? _uuid.v4() : announcement.id;
    var urls = [...announcement.imageUrls];
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uploaded = await _storeImage(
        announcementId: id,
        bytes: imageBytes,
        fileName: imageName ?? 'image.jpg',
      );
      if (uploaded != null) urls = [uploaded];
    }
    await _paths.announcements.doc(id).set(
      Announcement(
        id: id,
        title: announcement.title,
        body: announcement.body,
        audience: announcement.audience,
        classIds: announcement.classIds,
        imageUrls: urls,
        createdBy: announcement.createdBy,
      ).toMap(stampCreatedAt: isNew),
      SetOptions(merge: !isNew),
    );
  }

  Future<void> create(
    Announcement announcement, {
    Uint8List? imageBytes,
    String? imageName,
  }) {
    return save(announcement, imageBytes: imageBytes, imageName: imageName);
  }

  Future<String?> _storeImage({
    required String announcementId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref(
        'institutions/$institutionId/announcements/$announcementId/$fileName',
      );
      await ref.putData(bytes, SettableMetadata(contentType: _contentType(fileName)));
      return await ref.getDownloadURL();
    } catch (_) {
      if (bytes.lengthInBytes > _maxEmbeddedBytes) return null;
      final mime = _contentType(fileName);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> delete(String id) => _paths.announcements.doc(id).delete();
}
