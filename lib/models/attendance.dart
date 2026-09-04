import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, neutral }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.neutral:
        return 'Neutral / Pending';
    }
  }
}

AttendanceStatus attendanceStatusFromString(String? value) {
  return switch (value) {
    'present' => AttendanceStatus.present,
    'absent' => AttendanceStatus.absent,
    'neutral' => AttendanceStatus.neutral,
    'late' => AttendanceStatus.neutral,
    _ => AttendanceStatus.neutral,
  };
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.classId,
    required this.date,
    required this.marks,
    this.takenBy,
    this.markedAt,
  });

  final String id;
  final String classId;
  final String date;
  final Map<String, AttendanceStatus> marks;
  final String? takenBy;
  final DateTime? markedAt;

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    final raw = Map<String, dynamic>.from(data['marks'] as Map? ?? const {});
    final marked = data['markedAt'];
    return AttendanceRecord(
      id: id,
      classId: data['classId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      takenBy: data['takenBy'] as String?,
      markedAt: marked is Timestamp ? marked.toDate() : null,
      marks: raw.map(
        (key, value) =>
            MapEntry(key, attendanceStatusFromString(value as String?)),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'classId': classId,
    'date': date,
    'takenBy': takenBy,
    'marks': marks.map((key, value) => MapEntry(key, value.name)),
    if (markedAt != null) 'markedAt': Timestamp.fromDate(markedAt!),
  };
}

/// Attendance summary for a single student across [records].
class AttendanceStats {
  const AttendanceStats({
    required this.present,
    required this.absent,
    required this.pending,
  });

  /// Days marked present (working days).
  final int present;

  /// Days marked absent.
  final int absent;

  /// Days still pending / neutral (not counted against the student).
  final int pending;

  int get workingDays => present;

  /// Days with a definitive mark (present or absent).
  int get totalDays => present + absent;

  double? get percentage => totalDays == 0 ? null : present * 100 / totalDays;
}

AttendanceStats attendanceStatsFor(
  List<AttendanceRecord> records,
  String studentId,
) {
  var present = 0;
  var absent = 0;
  var pending = 0;
  for (final record in records) {
    final status = record.marks[studentId];
    if (status == AttendanceStatus.present) {
      present++;
    } else if (status == AttendanceStatus.absent) {
      absent++;
    } else if (status == AttendanceStatus.neutral) {
      pending++;
    }
  }
  return AttendanceStats(present: present, absent: absent, pending: pending);
}

/// Overall attendance percentage for [studentId] across [records].
///
/// Returns null when there are no marked days yet. Neutral / pending marks are
/// ignored so they don't count against the student.
double? attendancePercentageFor(
  List<AttendanceRecord> records,
  String studentId,
) {
  return attendanceStatsFor(records, studentId).percentage;
}
