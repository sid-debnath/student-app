import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance.dart';
import 'paths.dart';

class AttendanceRepository {
  AttendanceRepository(this.schoolId) : _paths = SchoolPaths(schoolId);

  final String schoolId;
  final SchoolPaths _paths;

  String docId(String classId, String date) => '${classId}_$date';

  Stream<AttendanceRecord?> watchDay(String classId, String date) {
    return _paths.attendance.doc(docId(classId, date)).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AttendanceRecord.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<AttendanceRecord>> watchForClass(String classId) {
    return _paths.attendance
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  Future<void> save(AttendanceRecord record) {
    return _paths.attendance
        .doc(docId(record.classId, record.date))
        .set(record.toMap(), SetOptions(merge: true));
  }
}
