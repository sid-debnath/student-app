import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/models/academic_class.dart';
import 'package:student_app/models/admin_dashboard.dart';
import 'package:student_app/models/app_user.dart';
import 'package:student_app/models/attendance.dart';
import 'package:student_app/models/homework.dart';
import 'package:student_app/models/student.dart';

void main() {
  final today = DateTime(2026, 9, 14);

  Student student(String id) =>
      Student(id: id, name: id, classId: 'c1', roll: '');

  AppUser user(String id, UserRole role) => AppUser(
    id: id,
    email: '$id@example.com',
    displayName: id,
    role: role,
    institutionId: 'default',
  );

  test('aggregates totals, today attendance, and rate', () {
    final data = computeAdminDashboard(
      students: [student('s1'), student('s2'), student('s3')],
      todayRecords: const [
        AttendanceRecord(
          id: 'c1_2026-09-14',
          classId: 'c1',
          date: '2026-09-14',
          marks: {
            's1': AttendanceStatus.present,
            's2': AttendanceStatus.absent,
            's3': AttendanceStatus.neutral,
          },
        ),
      ],
      classes: const [AcademicClass(id: 'c1', name: '10', section: 'A', year: 2026)],
      users: [user('t1', UserRole.teacher), user('f1', UserRole.floorIncharge), user('v1', UserRole.viewer)],
      homeworkItems: [],
      announcements: const [],
      today: today,
    );

    expect(data.totalStudents, 3);
    expect(data.presentToday, 1);
    expect(data.absentToday, 1);
    expect(data.markedToday, 2);
    expect(data.attendanceRateToday, 50);
    expect(data.totalClasses, 1);
    expect(data.staffCount, 2);
    expect(data.upcomingHomework, 0);
  });

  test('dedupes students across multiple class records', () {
    final data = computeAdminDashboard(
      students: [student('s1'), student('s2')],
      todayRecords: const [
        AttendanceRecord(
          id: 'c1_2026-09-14',
          classId: 'c1',
          date: '2026-09-14',
          marks: {'s1': AttendanceStatus.present},
        ),
        AttendanceRecord(
          id: 'c2_2026-09-14',
          classId: 'c2',
          date: '2026-09-14',
          marks: {'s1': AttendanceStatus.present, 's2': AttendanceStatus.absent},
        ),
      ],
      classes: const [],
      users: const [],
      homeworkItems: [],
      announcements: const [],
      today: today,
    );

    expect(data.presentToday, 1);
    expect(data.absentToday, 1);
  });

  test('attendance rate is null when nothing is marked', () {
    final data = computeAdminDashboard(
      students: [student('s1')],
      todayRecords: const [],
      classes: const [],
      users: const [],
      homeworkItems: [],
      announcements: const [],
      today: today,
    );

    expect(data.markedToday, 0);
    expect(data.attendanceRateToday, isNull);
  });

  test('counts only homework due today or later', () {
    Homework homework(String id, DateTime due) =>
        Homework(id: id, classId: 'c1', subject: 'Math', title: id, body: '', dueDate: due);

    final data = computeAdminDashboard(
      students: const [],
      todayRecords: const [],
      classes: const [],
      users: const [],
      homeworkItems: [
        homework('past', today.subtract(const Duration(days: 1))),
        homework('today', today),
        homework('future', today.add(const Duration(days: 3))),
      ],
      announcements: const [],
      today: today,
    );

    expect(data.upcomingHomework, 2);
  });
}
