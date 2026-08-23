class Exam {
  const Exam({
    required this.id,
    required this.name,
    required this.term,
    required this.classId,
    this.maxMarks = 100,
  });

  final String id;
  final String name;
  final String term;
  final String classId;
  final int maxMarks;

  factory Exam.fromMap(String id, Map<String, dynamic> data) {
    return Exam(
      id: id,
      name: data['name'] as String? ?? '',
      term: data['term'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      maxMarks: (data['maxMarks'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'term': term,
    'classId': classId,
    'maxMarks': maxMarks,
  };
}
