/// An exam sitting for a class, identified by [examType] (e.g. UT-1).
class Exam {
  const Exam({
    required this.id,
    required this.examType,
    required this.classId,
    this.maxMarks = 100,
  });

  final String id;

  /// Label such as `UT-1`, `Mid-Term`, etc.
  final String examType;
  final String classId;
  final int maxMarks;

  factory Exam.fromMap(String id, Map<String, dynamic> data) {
    final examType = (data['examType'] as String?)?.trim();
    final legacyName = (data['name'] as String?)?.trim();
    return Exam(
      id: id,
      examType: (examType != null && examType.isNotEmpty)
          ? examType
          : (legacyName ?? ''),
      classId: data['classId'] as String? ?? '',
      maxMarks: (data['maxMarks'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toMap() => {
    'examType': examType,
    'classId': classId,
    'maxMarks': maxMarks,
  };
}
