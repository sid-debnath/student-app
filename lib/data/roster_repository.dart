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

  /// Students/parents only see classes they are enrolled in.
  /// Floor in-charges are scoped to their assigned classes.
  Stream<List<AcademicClass>> watchVisibleClasses(AppUser user) {
    if (user.isFloorIncharge) {
      return watchClasses().map((items) => [
        for (final academicClass in items)
          if (user.classIds.contains(academicClass.id)) academicClass,
      ]);
    }
    if (!user.isViewer) return watchClasses();
    return Stream.multi((controller) {
      var classes = <AcademicClass>[];
      var allowedIds = <String>{};
      void emit() {
        controller.add(
          [
            for (final academicClass in classes)
              if (allowedIds.contains(academicClass.id)) academicClass,
          ],
        );
      }

      final classSub = watchClasses().listen((items) {
        classes = items;
        emit();
      }, onError: controller.addError);
      final studentSub = watchStudentsByIds(user.studentIds).listen((students) {
        allowedIds = {for (final student in students) student.classId};
        emit();
      }, onError: controller.addError);
      controller.onCancel = () {
        unawaited(classSub.cancel());
        unawaited(studentSub.cancel());
      };
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
    final payload = academicClass.toMap();
    if (academicClass.id.isEmpty) {
      await _paths.classes.doc(id).set(payload);
    } else {
      await _paths.classes.doc(id).set(payload, SetOptions(merge: true));
    }
  }

  Future<void> deleteClass(String id) => _paths.classes.doc(id).delete();

  Future<String> upsertStudent(Student student) async {
    final id = student.id.isEmpty ? _uuid.v4() : student.id;
    await _paths.students.doc(id).set(student.toMap(), SetOptions(merge: true));
    return id;
  }

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
    final studentSnap = await _paths.students.doc(studentId).get();
    final classId = studentSnap.data()?['classId'] as String?;
    await _paths.users.doc(viewerId).set({
      'studentIds': FieldValue.arrayUnion([studentId]),
      if (classId != null) 'classIds': FieldValue.arrayUnion([classId]),
    }, SetOptions(merge: true));
  }

  Future<void> updateUser({
    required AppUser user,
    required String displayName,
    required UserRole role,
    required List<String> classIds,
    required List<String> studentIds,
    String? fatherPhone,
    String? motherPhone,
    String? alternativePhone,
    ViewerAccountType? viewerAccountType,
  }) async {
    if (user.isAdmin && role != UserRole.admin) {
      await _ensureNotLastAdmin(user.id);
    }
    var nextClassIds =
        role == UserRole.teacher || role == UserRole.floorIncharge
            ? classIds
            : <String>[];
    final nextStudentIds = role == UserRole.viewer ? studentIds : <String>[];
    if (role == UserRole.viewer) {
      await _syncViewerLinks(user.id, nextStudentIds);
      final students = await watchStudents().first;
      nextClassIds = {
        for (final student in students)
          if (nextStudentIds.contains(student.id)) student.classId,
      }.toList();
    } else if (user.studentIds.isNotEmpty) {
      await _syncViewerLinks(user.id, const []);
    }
    if (role == UserRole.teacher || role == UserRole.floorIncharge) {
      await _syncTeacherClasses(user.id, nextClassIds);
    } else {
      await _syncTeacherClasses(user.id, const []);
    }
    final nextViewerType = role == UserRole.viewer
        ? (viewerAccountType ??
            user.viewerAccountType ??
            ((fatherPhone ?? user.fatherPhone).isNotEmpty ||
                    (motherPhone ?? user.motherPhone).isNotEmpty
                ? ViewerAccountType.parent
                : ViewerAccountType.student))
        : null;
    final phones = role == UserRole.viewer
        ? <String, dynamic>{
            'fatherPhone': fatherPhone ?? user.fatherPhone,
            'motherPhone': motherPhone ?? user.motherPhone,
            'alternativePhone': alternativePhone ?? user.alternativePhone,
            if (nextViewerType != null) 'viewerAccountType': nextViewerType.name,
          }
        : <String, dynamic>{
            'fatherPhone': '',
            'motherPhone': '',
            'alternativePhone': '',
            'viewerAccountType': FieldValue.delete(),
          };
    await _paths.users.doc(user.id).set({
      'displayName': displayName,
      'role': role.name,
      'classIds': nextClassIds,
      'studentIds': nextStudentIds,
      ...phones,
    }, SetOptions(merge: true));
  }

  Future<void> deleteStudent(String id) => deleteStudentCompletely(id);

  /// Removes a roster student, their attendance/marks/PTM rows, and any
  /// exclusive student login profiles linked only to this student.
  ///
  /// Returns exclusive [AppUser]s that still need Firebase Auth deletion by the
  /// caller (Auth cannot be deleted from this repository).
  Future<List<AppUser>> prepareStudentAccountDeletion(String studentId) async {
    final users = await watchUsers().first;
    return [
      for (final user in users)
        if (!user.isAdmin &&
            user.isViewer &&
            user.studentIds.length == 1 &&
            user.studentIds.first == studentId)
          user,
    ];
  }

  Future<void> deleteStudentCompletely(String studentId) async {
    final users = await watchUsers().first;
    for (final user in users) {
      if (user.isAdmin) continue;
      if (!user.studentIds.contains(studentId)) continue;
      if (user.isViewer &&
          user.studentIds.length == 1 &&
          user.studentIds.first == studentId) {
        // Exclusive student login profile — remove after Auth is deleted by caller.
        await _syncViewerLinks(user.id, const []);
        await _syncTeacherClasses(user.id, const []);
        await _paths.users.doc(user.id).delete();
      } else {
        final nextIds = [...user.studentIds]..remove(studentId);
        await _paths.students.doc(studentId).set({
          'viewerUids': FieldValue.arrayRemove([user.id]),
        }, SetOptions(merge: true));
        await _paths.users.doc(user.id).set({
          'studentIds': nextIds,
        }, SetOptions(merge: true));
      }
    }
    await _purgeStudentRelatedData(studentId);
  }

  Future<void> deleteUser(
    AppUser user, {
    required String actorUid,
    bool deleteOwnedStudents = true,
  }) async {
    if (user.id == actorUid) {
      throw StateError('You cannot delete the account you are signed in with.');
    }
    if (user.isAdmin) {
      await _ensureNotLastAdmin(user.id);
    }
    final ownedStudentIds = deleteOwnedStudents && user.isViewer
        ? [...user.studentIds]
        : <String>[];
    await _syncViewerLinks(user.id, const []);
    await _syncTeacherClasses(user.id, const []);
    await _paths.users.doc(user.id).delete();
    if (!deleteOwnedStudents || !user.isViewer) return;
    for (final studentId in ownedStudentIds) {
      final remaining = await watchUsers().first;
      final stillLinked = remaining.any(
        (other) => other.id != user.id && other.studentIds.contains(studentId),
      );
      if (stillLinked) continue;
      await _purgeStudentRelatedData(studentId);
    }
  }

  Future<void> _purgeStudentRelatedData(String studentId) async {
    final studentSnap = await _paths.students.doc(studentId).get();
    final classId = studentSnap.data()?['classId'] as String?;

    Future<void> deleteWhere(
      CollectionReference<Map<String, dynamic>> col,
    ) async {
      final snap = await col.where('studentId', isEqualTo: studentId).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    await deleteWhere(_paths.marks);
    await deleteWhere(_paths.reportCards);
    await deleteWhere(_paths.ptmBookings);
    await deleteWhere(_paths.ptmNotes);

    if (classId != null && classId.isNotEmpty) {
      final attendance = await _paths.attendance
          .where('classId', isEqualTo: classId)
          .get();
      for (final doc in attendance.docs) {
        final data = doc.data();
        final marks = Map<String, dynamic>.from(
          data['marks'] as Map? ?? const {},
        );
        if (!marks.containsKey(studentId)) continue;
        marks.remove(studentId);
        await doc.reference.update({'marks': marks});
      }
    }

    if (studentSnap.exists) {
      await _paths.students.doc(studentId).delete();
    }
  }

  Future<void> _ensureNotLastAdmin(String uid) async {
    final users = await watchUsers().first;
    final otherAdmins = users.where((item) => item.isAdmin && item.id != uid);
    if (otherAdmins.isEmpty) {
      throw StateError('Keep at least one admin account.');
    }
  }

  Future<void> _syncTeacherClasses(String teacherId, List<String> classIds) async {
    final classes = await watchClasses().first;
    final wanted = classIds.toSet();
    for (final academicClass in classes) {
      final has = academicClass.teacherIds.contains(teacherId);
      final shouldHave = wanted.contains(academicClass.id);
      if (has == shouldHave) continue;
      await _paths.classes.doc(academicClass.id).set({
        'teacherIds': shouldHave
            ? FieldValue.arrayUnion([teacherId])
            : FieldValue.arrayRemove([teacherId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _syncViewerLinks(String viewerId, List<String> studentIds) async {
    final students = await watchStudents().first;
    final wanted = studentIds.toSet();
    for (final student in students) {
      final has = student.viewerUids.contains(viewerId);
      final shouldHave = wanted.contains(student.id);
      if (has == shouldHave) continue;
      await _paths.students.doc(student.id).set({
        'viewerUids': shouldHave
            ? FieldValue.arrayUnion([viewerId])
            : FieldValue.arrayRemove([viewerId]),
      }, SetOptions(merge: true));
    }
  }
}
