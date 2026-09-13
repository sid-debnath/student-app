import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance.dart';
import 'paths.dart';

class AttendanceRepository {
  AttendanceRepository(this.institutionId)
    : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;

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
          (snap) =>
              snap.docs
                  .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  Future<void> save(AttendanceRecord record) {
    return _paths.attendance.doc(docId(record.classId, record.date)).set({
      ...record.toMap(),
      'markedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Deletes the entire attendance record for [classId] on [date].
  Future<void> deleteDay(String classId, String date) {
    return _paths.attendance.doc(docId(classId, date)).delete();
  }

  /// Removes a single student's mark from the [classId] attendance record for
  /// [date]. If that leaves no marks behind, the whole document is deleted.
  Future<void> deleteMark(String classId, String date, String studentId) async {
    final ref = _paths.attendance.doc(docId(classId, date));
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = Map<String, dynamic>.from(snap.data() ?? const {});
    final marks = Map<String, dynamic>.from(data['marks'] as Map? ?? const {});
    if (!marks.containsKey(studentId)) return;
    marks.remove(studentId);
    if (marks.isEmpty) {
      await ref.delete();
    } else {
      await ref.update({'marks': marks});
    }
  }
}
