import 'student.dart';

/// Students shown per page on the students list.
const int studentsPerPage = 40;

/// Number of pages needed to list [students] (0 when there is nothing to show).
int studentPageCount(List<Student> students) {
  if (students.isEmpty) return 0;
  return (students.length / studentsPerPage).ceil();
}

/// The slice of [students] shown on a zero-based [page].
///
/// [page] is clamped to the valid range so callers can pass a stale page number
/// (for example after a class is deleted or the list shrinks) without a range
/// error.
List<Student> studentsForPage(List<Student> students, int page) {
  if (students.isEmpty) return const [];
  final count = studentPageCount(students);
  final safePage = page.clamp(0, count - 1).toInt();
  final start = safePage * studentsPerPage;
  final end = (start + studentsPerPage) > students.length
      ? students.length
      : start + studentsPerPage;
  return students.sublist(start, end);
}
