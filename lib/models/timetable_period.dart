class TimetablePeriod {
  const TimetablePeriod({
    required this.id,
    required this.classId,
    required this.weekday,
    required this.start,
    required this.end,
    required this.subject,
    this.teacherId,
    this.teacherName,
  });

  final String id;
  final String classId;
  final int weekday;
  final String start;
  final String end;
  final String subject;
  final String? teacherId;
  final String? teacherName;

  factory TimetablePeriod.fromMap(String id, Map<String, dynamic> data) {
    return TimetablePeriod(
      id: id,
      classId: data['classId'] as String? ?? '',
      weekday: (data['weekday'] as num?)?.toInt() ?? 1,
      start: data['start'] as String? ?? '09:00',
      end: data['end'] as String? ?? '09:45',
      subject: data['subject'] as String? ?? '',
      teacherId: data['teacherId'] as String?,
      teacherName: data['teacherName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'weekday': weekday,
    'start': start,
    'end': end,
    'subject': subject,
    'teacherId': teacherId,
    'teacherName': teacherName,
  };
}

const weekdayLabels = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};
