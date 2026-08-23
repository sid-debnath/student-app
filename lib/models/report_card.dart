import 'package:cloud_firestore/cloud_firestore.dart';

class ReportCard {
  const ReportCard({
    required this.id,
    required this.studentId,
    required this.termId,
    required this.classId,
    required this.examName,
    required this.scores,
    required this.publishedAt,
    this.remarks,
    this.pdfPath,
  });

  final String id;
  final String studentId;
  final String termId;
  final String classId;
  final String examName;
  final Map<String, double> scores;
  final DateTime publishedAt;
  final String? remarks;
  final String? pdfPath;

  factory ReportCard.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
    final published = data['publishedAt'];
    return ReportCard(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      termId: data['termId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      examName: data['examName'] as String? ?? '',
      scores: raw.map((key, value) => MapEntry(key, (value as num).toDouble())),
      publishedAt: published is Timestamp
          ? published.toDate()
          : DateTime.tryParse('$published') ?? DateTime.now(),
      remarks: data['remarks'] as String?,
      pdfPath: data['pdfPath'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'termId': termId,
    'classId': classId,
    'examName': examName,
    'scores': scores,
    'publishedAt': Timestamp.fromDate(publishedAt),
    'remarks': remarks,
    'pdfPath': pdfPath,
  };
}
