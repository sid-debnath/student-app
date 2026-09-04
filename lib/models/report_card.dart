import 'package:cloud_firestore/cloud_firestore.dart';

class ReportCard {
  const ReportCard({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.examType,
    required this.scores,
    required this.publishedAt,
    this.remarks,
    this.imageUrl,
    this.pdfPath,
  });

  final String id;
  final String studentId;
  final String classId;
  final String examType;
  final Map<String, double> scores;
  final DateTime publishedAt;
  final String? remarks;
  final String? imageUrl;
  final String? pdfPath;

  factory ReportCard.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
    final published = data['publishedAt'];
    final examType = (data['examType'] as String?)?.trim();
    final legacyName = (data['examName'] as String?)?.trim();
    final legacyTerm = (data['termId'] as String?)?.trim();
    return ReportCard(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      examType: (examType != null && examType.isNotEmpty)
          ? examType
          : (legacyName?.isNotEmpty == true
              ? legacyName!
              : (legacyTerm ?? '')),
      scores: raw.map((key, value) => MapEntry(key, (value as num).toDouble())),
      publishedAt: published is Timestamp
          ? published.toDate()
          : DateTime.tryParse('$published') ?? DateTime.now(),
      remarks: data['remarks'] as String?,
      imageUrl: data['imageUrl'] as String? ?? data['reportImageUrl'] as String?,
      pdfPath: data['pdfPath'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'classId': classId,
    'examType': examType,
    'scores': scores,
    'publishedAt': Timestamp.fromDate(publishedAt),
    'remarks': remarks,
    'imageUrl': imageUrl,
    'pdfPath': pdfPath,
  };
}
