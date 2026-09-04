import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../models/exam.dart';
import '../models/marks.dart';
import '../models/report_card.dart';
import '../models/subject.dart';
import 'paths.dart';

 class MarksRepository {
  MarksRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<Subject>> watchSubjects() {
    return _paths.subjects.snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => Subject.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          if (byOrder != 0) return byOrder;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return items;
    });
  }

  Future<void> upsertSubject(Subject subject) async {
    final id = subject.id.isEmpty ? _uuid.v4() : subject.id;
    final order = subject.order;
    final nextOrder = order == 0 && subject.id.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : order;
    await _paths.subjects.doc(id).set(
      Subject(id: id, name: subject.name, order: nextOrder).toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteSubject(String id) => _paths.subjects.doc(id).delete();

  Stream<List<Exam>> watchExams({String? classId}) {
    Query<Map<String, dynamic>> query = _paths.exams;
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map((snap) {
      final items =
          snap.docs.map((doc) => Exam.fromMap(doc.id, doc.data())).toList()
            ..sort(
              (a, b) => a.examType.toLowerCase().compareTo(b.examType.toLowerCase()),
            );
      return items;
    });
  }

  Future<String> upsertExam(Exam exam) async {
    final id = exam.id.isEmpty ? _uuid.v4() : exam.id;
    await _paths.exams.doc(id).set(exam.toMap(), SetOptions(merge: true));
    return id;
  }

  /// Finds an existing exam for [classId] + [examType], or creates one.
  Future<Exam> ensureExamType({
    required String classId,
    required String examType,
  }) async {
    final label = examType.trim();
    if (label.isEmpty) {
      throw StateError('Exam type is required.');
    }
    final existing = await watchExams(classId: classId).first;
    for (final exam in existing) {
      if (exam.examType.toLowerCase() == label.toLowerCase()) {
        return exam;
      }
    }
    final id = await upsertExam(
      Exam(id: '', examType: label, classId: classId),
    );
    return Exam(id: id, examType: label, classId: classId);
  }

  Stream<List<StudentMarks>> watchMarks(String examId) {
    return _paths.marks.where('examId', isEqualTo: examId).snapshots().map(
          (snap) => snap.docs
              .map((doc) => StudentMarks.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> upsertMarks(StudentMarks marks) {
    final id = marks.id.isEmpty ? '${marks.examId}_${marks.studentId}' : marks.id;
    return _paths.marks.doc(id).set(marks.copyWith(id: id).toMap(), SetOptions(merge: true));
  }

  Future<void> saveClassMarks({
    required Exam exam,
    required List<StudentMarks> rows,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final row in rows) {
      final id = row.id.isEmpty ? '${exam.id}_${row.studentId}' : row.id;
      final ref = _paths.marks.doc(id);
      batch.set(
        ref,
        row
            .copyWith(
              id: id,
              examId: exam.id,
              classId: exam.classId,
              examType: exam.examType,
            )
            .toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Optional report-card image. Soft-fails on Spark / missing Storage.
  Future<String?> uploadReportImage({
    required String studentId,
    required String examId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!AppConfig.useStorage) return null;
    try {
      final safeName = fileName.isEmpty ? 'report.jpg' : fileName;
      final ref = FirebaseStorage.instance.ref(
        'institutions/$institutionId/reportCards/$examId/$studentId/$safeName',
      );
      await ref.putData(bytes, SettableMetadata(contentType: _contentType(safeName)));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Stream<List<ReportCard>> watchReportCards({String? studentId}) {
    Query<Map<String, dynamic>> query = _paths.reportCards;
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => ReportCard.fromMap(doc.id, doc.data())).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
    );
  }

  Future<void> publishReportCard(ReportCard card) {
    final id = card.id.isEmpty
        ? '${card.studentId}_${card.examType}'.replaceAll(' ', '_')
        : card.id;
    return _paths.reportCards.doc(id).set(card.toMap(), SetOptions(merge: true));
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
