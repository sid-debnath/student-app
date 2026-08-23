import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/school_class.dart';
import '../models/student.dart';
import 'paths.dart';

class RosterRepository {
  RosterRepository(this.schoolId) : _paths = SchoolPaths(schoolId);

  final String schoolId;
  final SchoolPaths _paths;
  final _uuid = const Uuid();

  Stream<List<SchoolClass>> watchClasses({List<String>? onlyIds}) {
    return _paths.classes.orderBy('name').snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => SchoolClass.fromMap(doc.id, doc.data()))
          .toList();
      if (onlyIds == null) return items;
      return items.where((item) => onlyIds.contains(item.id)).toList();
    });
  }

  Stream<List<Student>> watchStudents({String? classId}) {
    Query<Map<String, dynamic>> query = _paths.students;
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => Student.fromMap(doc.id, doc.data())).toList()
        ..sort((a, b) => a.roll.compareTo(b.roll)),
    );
  }

  Stream<Student?> watchStudent(String studentId) {
    return _paths.students.doc(studentId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Student.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<AppUser>> watchUsers() {
    return _paths.users.snapshots().map(
      (snap) => snap.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName)),
    );
  }

  Future<void> upsertClass(SchoolClass schoolClass) async {
    final id = schoolClass.id.isEmpty ? _uuid.v4() : schoolClass.id;
    await _paths.classes.doc(id).set(schoolClass.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteClass(String id) => _paths.classes.doc(id).delete();

  Future<void> upsertStudent(Student student) async {
    final id = student.id.isEmpty ? _uuid.v4() : student.id;
    await _paths.students.doc(id).set(student.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteStudent(String id) => _paths.students.doc(id).delete();

  Future<void> assignTeacher({
    required String classId,
    required String teacherId,
  }) async {
    await _paths.classes.doc(classId).set({
      'teacherIds': FieldValue.arrayUnion([teacherId]),
    }, SetOptions(merge: true));
    await _paths.users.doc(teacherId).set({
      'classIds': FieldValue.arrayUnion([classId]),
    }, SetOptions(merge: true));
  }

  Future<void> linkViewer({
    required String studentId,
    required String viewerId,
  }) async {
    await _paths.students.doc(studentId).set({
      'viewerUids': FieldValue.arrayUnion([viewerId]),
    }, SetOptions(merge: true));
    await _paths.users.doc(viewerId).set({
      'studentIds': FieldValue.arrayUnion([studentId]),
    }, SetOptions(merge: true));
  }
}
