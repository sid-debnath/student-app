import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/academic_class.dart';
import '../models/student.dart';
import 'paths.dart';

class RosterRepository {
  RosterRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<AcademicClass>> watchClasses() {
    return _paths.classes.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => AcademicClass.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byName = a.name.compareTo(b.name);
          if (byName != 0) return byName;
          return a.section.compareTo(b.section);
        });
      return items;
    });
  }

  Future<String?> selectedOrFirstClassId(String? selectedId) async {
    final classes = await watchClasses().first;
    if (classes.any((item) => item.id == selectedId)) return selectedId;
    return classes.isEmpty ? null : classes.first.id;
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

  Stream<List<Student>> watchStudentsByIds(List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    return Stream.multi((controller) {
      final latest = <String, Student?>{for (final id in ids) id: null};
      final subs = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
      void emit() {
        final list = [
          for (final id in ids)
            if (latest[id] != null) latest[id]!,
        ]..sort((a, b) => a.roll.compareTo(b.roll));
        controller.add(list);
      }

      for (final id in ids) {
        subs.add(
          _paths.students.doc(id).snapshots().listen((snap) {
            latest[id] = snap.exists && snap.data() != null
                ? Student.fromMap(snap.id, snap.data()!)
                : null;
            emit();
          }, onError: controller.addError),
        );
      }
      controller.onCancel = () {
        for (final sub in subs) {
          unawaited(sub.cancel());
        }
      };
    });
  }

  Stream<List<AppUser>> watchUsers() {
    return _paths.users.snapshots().map(
      (snap) => snap.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName)),
    );
  }

  Future<void> upsertClass(AcademicClass academicClass) async {
    final id = academicClass.id.isEmpty ? _uuid.v4() : academicClass.id;
    await _paths.classes.doc(id).set(academicClass.toMap(), SetOptions(merge: true));
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
