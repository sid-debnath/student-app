import 'package:cloud_firestore/cloud_firestore.dart';

/// An exam sitting for a class, identified by [examType] (e.g. UT-1).
///
/// When an admin saves marks for a class, the repository also stores a
/// class-level analytics snapshot on this document so viewers (students and
/// parents) can see their own percentage plus the class topper, lowest marks
/// and class average without being able to read their classmates' raw marks.
class Exam {
  const Exam({
    required this.id,
    required this.examType,
    required this.classId,
    this.maxMarks = 100,
    this.classAverage,
    this.classHighest,
    this.classLowest,
    this.topperName,
    this.topperStudentId,
    this.lowestName,
    this.lowestStudentId,
    this.analyticsUpdatedAt,
  });

  final String id;

  /// Label such as `UT-1`, `Mid-Term`, etc.
  final String examType;
  final String classId;
  final int maxMarks;

  /// Mean percentage across students who have marks for this exam.
  final double? classAverage;

  /// Highest percentage in the class (the class topper's percentage).
  final double? classHighest;

  /// Lowest percentage in the class.
  final double? classLowest;

  final String? topperName;
  final String? topperStudentId;
  final String? lowestName;
  final String? lowestStudentId;
  final DateTime? analyticsUpdatedAt;

  /// Whether a class-level analytics snapshot has been stored.
  bool get hasAnalytics =>
      classHighest != null && classLowest != null && classAverage != null;

  factory Exam.fromMap(String id, Map<String, dynamic> data) {
    final examType = (data['examType'] as String?)?.trim();
    final legacyName = (data['name'] as String?)?.trim();
    final analytics = data['analyticsUpdatedAt'];
    return Exam(
      id: id,
      examType: (examType != null && examType.isNotEmpty)
          ? examType
          : (legacyName ?? ''),
      classId: data['classId'] as String? ?? '',
      maxMarks: (data['maxMarks'] as num?)?.toInt() ?? 100,
      classAverage: (data['classAverage'] as num?)?.toDouble(),
      classHighest: (data['classHighest'] as num?)?.toDouble(),
      classLowest: (data['classLowest'] as num?)?.toDouble(),
      topperName: data['topperName'] as String?,
      topperStudentId: data['topperStudentId'] as String?,
      lowestName: data['lowestName'] as String?,
      lowestStudentId: data['lowestStudentId'] as String?,
      analyticsUpdatedAt: analytics is Timestamp
          ? analytics.toDate()
          : (analytics == null ? null : DateTime.tryParse('$analytics')),
    );
  }

  Map<String, dynamic> toMap() => {
    'examType': examType,
    'classId': classId,
    'maxMarks': maxMarks,
    if (classAverage != null) 'classAverage': classAverage,
    if (classHighest != null) 'classHighest': classHighest,
    if (classLowest != null) 'classLowest': classLowest,
    if (topperName != null) 'topperName': topperName,
    if (topperStudentId != null) 'topperStudentId': topperStudentId,
    if (lowestName != null) 'lowestName': lowestName,
    if (lowestStudentId != null) 'lowestStudentId': lowestStudentId,
    if (analyticsUpdatedAt != null)
      'analyticsUpdatedAt': Timestamp.fromDate(analyticsUpdatedAt!),
  };
}

