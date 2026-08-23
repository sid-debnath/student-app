import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/exam.dart';
import '../models/marks.dart';
import '../models/report_card.dart';
import 'paths.dart';

class MarksRepository {
  MarksRepository(this.institutionId) : _paths = InstitutionPaths(institutionId);

  final String institutionId;
  final InstitutionPaths _paths;
  final _uuid = const Uuid();

  Stream<List<Exam>> watchExams({String? classId}) {
    Query<Map<String, dynamic>> query = _paths.exams;
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map((doc) => Exam.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> upsertExam(Exam exam) async {
    final id = exam.id.isEmpty ? _uuid.v4() : exam.id;
    await _paths.exams.doc(id).set(exam.toMap(), SetOptions(merge: true));
  }

  Stream<List<StudentMarks>> watchMarks(String examId) {
    return _paths.marks
        .where('examId', isEqualTo: examId)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => StudentMarks.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<void> upsertMarks(StudentMarks marks) {
    final id = marks.id.isEmpty ? '${marks.examId}_${marks.studentId}' : marks.id;
    return _paths.marks.doc(id).set(marks.toMap(), SetOptions(merge: true));
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
    final id = card.id.isEmpty ? '${card.studentId}_${card.termId}' : card.id;
    return _paths.reportCards.doc(id).set(card.toMap(), SetOptions(merge: true));
  }
}
