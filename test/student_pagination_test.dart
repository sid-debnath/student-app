import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/models/student.dart';
import 'package:student_app/models/student_pagination.dart';

void main() {
  List<Student> make(int count) => List.generate(
    count,
    (i) => Student(id: 's$i', name: 'Student $i', classId: 'c1', roll: '$i'),
  );

  test('single page for 40 or fewer students', () {
    expect(studentPageCount(make(0)), 0);
    expect(studentPageCount(make(1)), 1);
    expect(studentPageCount(make(40)), 1);
  });

  test('multiple pages when a class has more than 40 students', () {
    expect(studentPageCount(make(41)), 2);
    expect(studentPageCount(make(80)), 2);
    expect(studentPageCount(make(81)), 3);
  });

  test('studentsForPage returns 40 per page with a partial final page', () {
    final students = make(95);
    expect(studentsForPage(students, 0).length, 40);
    expect(studentsForPage(students, 1).length, 40);
    expect(studentsForPage(students, 2).length, 15);
  });

  test('studentsForPage clamps out-of-range pages instead of throwing', () {
    final students = make(95);
    expect(studentsForPage(students, 99).first.id, students[80].id);
    expect(studentsForPage(students, -1).first.id, students[0].id);
  });

  test('studentsForPage handles an empty list', () {
    expect(studentsForPage(const [], 0), isEmpty);
  });
}
