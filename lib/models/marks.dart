class MarkScore {
  const MarkScore({
    required this.obtained,
    required this.maximum,
  });

  final double obtained;
  final double maximum;

  factory MarkScore.fromMap(Map<String, dynamic> data) {
    return MarkScore(
      obtained: (data['obtained'] as num?)?.toDouble() ?? 0,
      maximum: (data['maximum'] as num?)?.toDouble() ?? 100,
    );
  }

  Map<String, dynamic> toMap() => {
        'obtained': obtained,
        'maximum': maximum,
      };

  String get display {
    String format(double value) {
      return value == value.roundToDouble()
          ? '${value.round()}'
          : value.toString();
    }

    return '${format(obtained)}/${format(maximum)}';
  }
}

class StudentMarks {
  const StudentMarks({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.classId,
    required this.scores,
    this.examType = '',
    this.reportImageUrl,
  });

  final String id;
  final String examId;
  final String studentId;
  final String classId;

  final Map<String, MarkScore> scores;

  final String examType;
  final String? reportImageUrl;

  double get total =>
      scores.values.fold(0, (sum, value) => sum + value.obtained);

  factory StudentMarks.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(
      data['scores'] as Map? ?? const {},
    );

    return StudentMarks(
      id: id,
      examId: data['examId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      examType: data['examType'] as String? ?? '',
      scores: raw.map((key, value) {
        if (value is Map) {
          return MapEntry(
            key,
            MarkScore.fromMap(
              Map<String, dynamic>.from(value),
            ),
          );
        }

        // Keeps old marks compatible.
        final oldValue = (value as num).toDouble();

        return MapEntry(
          key,
          MarkScore(
            obtained: oldValue,
            maximum: 100,
          ),
        );
      }),
      reportImageUrl: data['reportImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'examId': examId,
        'studentId': studentId,
        'classId': classId,
        'examType': examType,
        'scores': scores.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
        if (reportImageUrl != null) 'reportImageUrl': reportImageUrl,
      };

  StudentMarks copyWith({
    String? id,
    String? examId,
    String? studentId,
    String? classId,
    Map<String, MarkScore>? scores,
    String? examType,
    String? reportImageUrl,
    bool clearReportImageUrl = false,
  }) {
    return StudentMarks(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      classId: classId ?? this.classId,
      scores: scores ?? this.scores,
      examType: examType ?? this.examType,
      reportImageUrl: clearReportImageUrl
          ? null
          : (reportImageUrl ?? this.reportImageUrl),
    );
  }
}