enum AttendanceStatus { present, absent, late }

AttendanceStatus attendanceStatusFromString(String? value) {
  return AttendanceStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => AttendanceStatus.absent,
  );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.classId,
    required this.date,
    required this.marks,
    this.takenBy,
  });

  final String id;
  final String classId;
  final String date;
  final Map<String, AttendanceStatus> marks;
  final String? takenBy;

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(data['marks'] as Map? ?? const {});
    return AttendanceRecord(
      id: id,
      classId: data['classId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      takenBy: data['takenBy'] as String?,
      marks: raw.map(
        (key, value) => MapEntry(key, attendanceStatusFromString(value as String?)),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'date': date,
    'takenBy': takenBy,
    'marks': marks.map((key, value) => MapEntry(key, value.name)),
  };
}
