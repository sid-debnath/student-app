class StudentMarks {
  const StudentMarks({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.classId,
    required this.scores,
  });

  final String id;
  final String examId;
  final String studentId;
  final String classId;
  final Map<String, double> scores;

  double get total => scores.values.fold(0, (sum, value) => sum + value);

  factory StudentMarks.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
    return StudentMarks(
      id: id,
      examId: data['examId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      scores: raw.map((key, value) => MapEntry(key, (value as num).toDouble())),
    );
  }

  Map<String, dynamic> toMap() => {
    'examId': examId,
    'studentId': studentId,
    'classId': classId,
    'scores': scores,
  };
}
