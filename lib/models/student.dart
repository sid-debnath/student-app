class Student {
  const Student({
    required this.id,
    required this.name,
    required this.classId,
    required this.roll,
    this.viewerUids = const [],
  });

  final String id;
  final String name;
  final String classId;
  final String roll;
  final List<String> viewerUids;

  factory Student.fromMap(String id, Map<String, dynamic> data) {
    return Student(
      id: id,
      name: data['name'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      roll: data['roll'] as String? ?? '',
      viewerUids: List<String>.from(data['viewerUids'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'classId': classId,
    'roll': roll,
    'viewerUids': viewerUids,
  };
}
