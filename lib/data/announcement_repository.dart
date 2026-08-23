import 'package:uuid/uuid.dart';

import '../models/announcement.dart';
import 'paths.dart';

class AnnouncementRepository {
  AnnouncementRepository(this.schoolId) : _paths = SchoolPaths(schoolId);

  final String schoolId;
  final SchoolPaths _paths;
  final _uuid = const Uuid();

  Stream<List<Announcement>> watch() {
    return _paths.announcements.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => Announcement.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Future<void> create(Announcement announcement) async {
    final id = announcement.id.isEmpty ? _uuid.v4() : announcement.id;
    await _paths.announcements.doc(id).set(announcement.toMap());
  }

  Future<void> delete(String id) => _paths.announcements.doc(id).delete();
}
