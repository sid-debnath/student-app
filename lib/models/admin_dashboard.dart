import 'academic_class.dart';
import 'announcement.dart';
import 'app_user.dart';
import 'attendance.dart';
import 'homework.dart';
import 'student.dart';

/// Snapshot of the admin home dashboard.
///
/// It is computed by [computeAdminDashboard] from the live institution data so
/// the numbers stay testable without touching Firestore.
class AdminDashboardData {
  const AdminDashboardData({
    this.totalStudents = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.totalClasses = 0,
    this.staffCount = 0,
    this.upcomingHomework = 0,
    this.announcements = const [],
  });

  /// Total students registered in the institution.
  final int totalStudents;

  /// Distinct students marked present in today's attendance records.
  final int presentToday;

  /// Distinct students marked absent in today's attendance records.
  final int absentToday;

  /// Number of classes / sections.
  final int totalClasses;

  /// Teachers + floor in-charges.
  final int staffCount;

  /// Homework whose due date is today or later.
  final int upcomingHomework;

  /// Announcements, newest first.
  final List<Announcement> announcements;

  /// Students with a definitive mark today (present + absent).
  int get markedToday => presentToday + absentToday;

  /// Today's attendance percentage, or null when nothing has been marked yet.
  double? get attendanceRateToday =>
      markedToday == 0 ? null : presentToday * 100 / markedToday;

  static const empty = AdminDashboardData();
}

/// Aggregates the raw institution data into [AdminDashboardData].
///
/// Present / absent are deduplicated by student id, so a student is counted
/// once even if they appear in more than one class record.
AdminDashboardData computeAdminDashboard({
  required List<Student> students,
  required List<AttendanceRecord> todayRecords,
  required List<AcademicClass> classes,
  required List<AppUser> users,
  required List<Homework> homeworkItems,
  required List<Announcement> announcements,
  required DateTime today,
}) {
  final present = <String>{};
  final absent = <String>{};
  for (final record in todayRecords) {
    for (final entry in record.marks.entries) {
      if (entry.value == AttendanceStatus.present) {
        present.add(entry.key);
      } else if (entry.value == AttendanceStatus.absent) {
        absent.add(entry.key);
      }
    }
  }

  final startOfToday = DateTime(today.year, today.month, today.day);
  final upcoming = homeworkItems
      .where((item) => !item.dueDate.isBefore(startOfToday))
      .length;

  return AdminDashboardData(
    totalStudents: students.length,
    presentToday: present.length,
    absentToday: absent.length,
    totalClasses: classes.length,
    staffCount: users.where((user) => user.isStaff).length,
    upcomingHomework: upcoming,
    announcements: announcements,
  );
}
