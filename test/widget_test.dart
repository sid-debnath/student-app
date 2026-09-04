import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/app_config.dart';
import 'package:student_app/core/theme.dart';
import 'package:student_app/data/auth_repository.dart';
import 'package:student_app/models/app_user.dart';
import 'package:student_app/models/attendance.dart';
import 'package:student_app/models/exam.dart';
import 'package:student_app/models/marks.dart';
import 'package:student_app/models/report_card.dart';
import 'package:student_app/models/subject.dart';

void main() {
  test('app theme uses Material 3', () {
    expect(buildAppTheme().useMaterial3, isTrue);
  });

  test('default edition is Spark (no-cost)', () {
    expect(AppConfig.isSpark, isTrue);
    expect(AppConfig.isProduction, isFalse);
    expect(AppConfig.useCloudFunctions, isFalse);
    expect(AppConfig.useStorage, isFalse);
    expect(AppConfig.useServerFcm, isFalse);
  });

  test('attendance supports present, absent, and neutral pending states', () {
    expect(AttendanceStatus.values, hasLength(3));
    expect(AttendanceStatus.neutral.label, 'Neutral / Pending');
    expect(attendanceStatusFromString('late'), AttendanceStatus.neutral);
    expect(attendanceStatusFromString(null), AttendanceStatus.neutral);
  });

  test('attendance percentage counts present over marked days and ignores pending', () {
    final records = [
      const AttendanceRecord(
        id: 'c1_2026-01-01',
        classId: 'c1',
        date: '2026-01-01',
        marks: {
          's1': AttendanceStatus.present,
          's2': AttendanceStatus.present,
        },
      ),
      const AttendanceRecord(
        id: 'c1_2026-01-02',
        classId: 'c1',
        date: '2026-01-02',
        marks: {
          's1': AttendanceStatus.absent,
          's2': AttendanceStatus.neutral,
        },
      ),
      const AttendanceRecord(
        id: 'c1_2026-01-03',
        classId: 'c1',
        date: '2026-01-03',
        marks: {'s1': AttendanceStatus.neutral},
      ),
    ];

    // s1: 1 present + 1 absent = 50%. s2: 1 present only = 100%.
    expect(attendancePercentageFor(records, 's1'), closeTo(50, 0.001));
    expect(attendancePercentageFor(records, 's2'), closeTo(100, 0.001));
    // Never marked -> null.
    expect(attendancePercentageFor(records, 's3'), isNull);
  });

  test('attendance percentage returns null when nothing is marked', () {
    expect(attendancePercentageFor(const [], 's1'), isNull);
    expect(
      attendancePercentageFor(
        const [
          AttendanceRecord(
            id: 'c1_2026-01-01',
            classId: 'c1',
            date: '2026-01-01',
            marks: {'s1': AttendanceStatus.neutral},
          ),
        ],
        's1',
      ),
      isNull,
    );
  });

  test('attendance stats expose working days, total days, and percentage', () {
    final stats = attendanceStatsFor(
      const [
        AttendanceRecord(
          id: 'c1_2026-01-01',
          classId: 'c1',
          date: '2026-01-01',
          marks: {'s1': AttendanceStatus.present},
        ),
        AttendanceRecord(
          id: 'c1_2026-01-02',
          classId: 'c1',
          date: '2026-01-02',
          marks: {'s1': AttendanceStatus.absent},
        ),
        AttendanceRecord(
          id: 'c1_2026-01-03',
          classId: 'c1',
          date: '2026-01-03',
          marks: {'s1': AttendanceStatus.neutral},
        ),
      ],
      's1',
    );
    expect(stats.workingDays, 1);
    expect(stats.totalDays, 2);
    expect(stats.pending, 1);
    expect(stats.percentage, closeTo(50, 0.001));
  });

  test('attendance record parses markedAt timestamp and omits it when missing', () {
    final record = AttendanceRecord.fromMap('c1_2026-01-01', {
      'classId': 'c1',
      'date': '2026-01-01',
      'takenBy': 't1',
      'markedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 9, 15)),
      'marks': {'s1': 'present'},
    });
    expect(
      record.markedAt?.millisecondsSinceEpoch,
      DateTime.utc(2026, 1, 1, 9, 15).millisecondsSinceEpoch,
    );
    expect(record.marks['s1'], AttendanceStatus.present);
    expect(AttendanceRecord.fromMap('x', {}).markedAt, isNull);
  });

  test('teachers, floor in-charges, and viewers must change temp password until explicitly cleared', () {
    AppUser user({required UserRole role, bool? mustChange}) {
      return AppUser(
        id: 'u1',
        email: 'a@b.c',
        displayName: 'A',
        role: role,
        institutionId: 'default',
        mustChangePassword: mustChange,
      );
    }

    expect(
      user(role: UserRole.teacher, mustChange: true)
          .requiresFirstLoginPasswordChange,
      isTrue,
    );
    expect(
      user(role: UserRole.floorIncharge, mustChange: true)
          .requiresFirstLoginPasswordChange,
      isTrue,
    );
    expect(
      user(role: UserRole.viewer, mustChange: true)
          .requiresFirstLoginPasswordChange,
      isTrue,
    );
    expect(
      user(role: UserRole.viewer, mustChange: null)
          .requiresFirstLoginPasswordChange,
      isTrue,
    );
    expect(
      user(role: UserRole.admin, mustChange: null)
          .requiresFirstLoginPasswordChange,
      isFalse,
    );
    expect(
      user(role: UserRole.floorIncharge, mustChange: false)
          .requiresFirstLoginPasswordChange,
      isFalse,
    );
  });

  test('parent phones parse from Firestore and hide empty alternative', () {
    final parent = AppUser.fromMap('p1', {
      'email': 'parent@school.test',
      'displayName': 'Sharma',
      'role': 'viewer',
      'institutionId': 'default',
      'viewerAccountType': 'parent',
      'fatherPhone': '9000000001',
      'motherPhone': '9000000002',
      'alternativePhone': '',
      'studentIds': ['s1'],
    });
    expect(parent.isParentAccount, isTrue);
    expect(parent.isStudentAccount, isFalse);
    expect(parent.fatherPhone, '9000000001');
    expect(parent.motherPhone, '9000000002');
    expect(parent.alternativePhone, isEmpty);
    expect(parent.hasParentPhones, isTrue);
    expect(parent.toMap()['alternativePhone'], '');
  });

  test('legacy primaryMobile maps to alternativePhone', () {
    final parent = AppUser.fromMap('p2', {
      'email': 'parent@school.test',
      'displayName': 'Legacy',
      'role': 'viewer',
      'fatherMobile': '111',
      'motherMobile': '222',
      'primaryMobile': '333',
    });
    expect(parent.fatherPhone, '111');
    expect(parent.motherPhone, '222');
    expect(parent.alternativePhone, '333');
    expect(parent.isParentAccount, isTrue);
  });

  test('student viewer account is not treated as parent', () {
    final student = AppUser.fromMap('s1', {
      'email': 'student@school.test',
      'displayName': 'Asha',
      'role': 'viewer',
      'viewerAccountType': 'student',
      'studentIds': ['stu1'],
    });
    expect(student.isStudentAccount, isTrue);
    expect(student.isParentAccount, isFalse);
  });

  group('first-login password reuse validation', () {
    test('rejects reusing temporary password 123456', () {
      expect(
        () => AuthRepository.validateFirstLoginNewPassword(
          newPassword: '123456',
          temporaryPassword: '123456',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cannot be the same as the temporary password'),
          ),
        ),
      );
    });

    test('rejects missing temporary password (previous bypass)', () {
      // Reproduction of the bug: null temp used to skip the equality check and
      // allow updatePassword(123456) + mustChangePassword=false to complete.
      expect(
        () => AuthRepository.validateFirstLoginNewPassword(
          newPassword: '123456',
          temporaryPassword: null,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Enter the temporary password'),
          ),
        ),
      );
      expect(
        () => AuthRepository.validateFirstLoginNewPassword(
          newPassword: '123456',
          temporaryPassword: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows a different new password when temporary is known', () {
      expect(
        () => AuthRepository.validateFirstLoginNewPassword(
          newPassword: 'private-789',
          temporaryPassword: '123456',
        ),
        returnsNormally,
      );
    });
  });

  group('marks models', () {
    test('exam type prefers examType over legacy name', () {
      final exam = Exam.fromMap('e1', {
        'examType': 'UT-1',
        'name': 'Term exam',
        'term': 'Term 1',
        'classId': 'c1',
      });
      expect(exam.examType, 'UT-1');
      expect(exam.toMap().containsKey('term'), isFalse);
      expect(exam.toMap().containsKey('name'), isFalse);
    });

    test('legacy exam name maps to examType', () {
      final exam = Exam.fromMap('e2', {
        'name': 'Mid-Term',
        'classId': 'c1',
      });
      expect(exam.examType, 'Mid-Term');
    });

    test('student marks store scores by subject id and optional image', () {
      final row = StudentMarks.fromMap('m1', {
        'examId': 'e1',
        'studentId': 's1',
        'classId': 'c1',
        'examType': 'UT-1',
        'scores': {'sub-english': 88, 'sub-maths': 91},
        'reportImageUrl': 'https://example.test/r.jpg',
      });
      expect(row.scores['sub-english']?.obtained, 88);
      expect(row.reportImageUrl, contains('r.jpg'));
      expect(row.toMap()['examType'], 'UT-1');
    });

    test('report card reads examType and imageUrl with legacy fallbacks', () {
      final card = ReportCard.fromMap('r1', {
        'studentId': 's1',
        'classId': 'c1',
        'examName': 'Old exam',
        'termId': 'Term 1',
        'scores': {'English': 80},
        'publishedAt': DateTime(2026, 1, 2).toIso8601String(),
        'reportImageUrl': 'https://example.test/legacy.png',
      });
      expect(card.examType, 'Old exam');
      expect(card.imageUrl, contains('legacy.png'));
    });

    test('subject model round-trips', () {
      final subject = Subject.fromMap('sub1', {'name': 'Science', 'order': 2});
      expect(subject.name, 'Science');
      expect(subject.toMap()['order'], 2);
    });
  });
}
