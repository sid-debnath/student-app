import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/announcement_repository.dart';
import '../data/attendance_repository.dart';
import '../data/auth_repository.dart';
import '../data/homework_repository.dart';
import '../data/marks_repository.dart';
import '../data/roster_repository.dart';
import '../data/timetable_repository.dart';
import '../models/academic_class.dart';
import '../models/admin_dashboard.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/homework.dart';
import '../models/institution.dart';
import '../models/student.dart';
import 'app_theme.dart';
import 'branding.dart';

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull => value;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final sessionProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(user);
});

final selectedStudentIdProvider = NotifierProvider<SelectedStudentId, String?>(
  SelectedStudentId.new,
);

class SelectedStudentId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final institutionIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider).valueOrNull?.institutionId;
});

final institutionProvider = StreamProvider<Institution?>((ref) {
  if (ref.watch(sessionProvider).valueOrNull == null) {
    return Stream.value(null);
  }
  return ref.watch(authRepositoryProvider).watchInstitution();
});

final brandConfigProvider = Provider<BrandConfig>((ref) {
  final remote = ref.watch(institutionProvider).valueOrNull;
  return BrandConfig.current.mergeInstitution(remote);
});

final themeProvider = Provider<AppTheme>((ref) {
  final id = ref.watch(sessionProvider).valueOrNull?.preferences.themeId;
  return appThemeFromId(id);
});

final rosterRepositoryProvider = Provider<RosterRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : RosterRepository(institutionId);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : AttendanceRepository(institutionId);
});

final homeworkRepositoryProvider = Provider<HomeworkRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : HomeworkRepository(institutionId);
});

final timetableRepositoryProvider = Provider<TimetableRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : TimetableRepository(institutionId);
});

final marksRepositoryProvider = Provider<MarksRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : MarksRepository(institutionId);
});

final announcementRepositoryProvider = Provider<AnnouncementRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : AnnouncementRepository(institutionId);
});

/// Combined live snapshot backing the admin home dashboard.
final adminDashboardProvider = StreamProvider<AdminDashboardData>((ref) {
  final roster = ref.watch(rosterRepositoryProvider);
  final attendance = ref.watch(attendanceRepositoryProvider);
  final homework = ref.watch(homeworkRepositoryProvider);
  final announcements = ref.watch(announcementRepositoryProvider);
  if (roster == null ||
      attendance == null ||
      homework == null ||
      announcements == null) {
    return Stream.value(AdminDashboardData.empty);
  }
  return _watchAdminDashboard(
    roster: roster,
    attendance: attendance,
    homework: homework,
    announcements: announcements,
    today: DateTime.now(),
  );
});

Stream<AdminDashboardData> _watchAdminDashboard({
  required RosterRepository roster,
  required AttendanceRepository attendance,
  required HomeworkRepository homework,
  required AnnouncementRepository announcements,
  required DateTime today,
}) {
  final dateKey = DateFormat('yyyy-MM-dd').format(today);
  return Stream.multi((controller) {
    var students = <Student>[];
    var todayRecords = <AttendanceRecord>[];
    var classes = <AcademicClass>[];
    var users = <AppUser>[];
    var homeworkItems = <Homework>[];
    var announcementItems = <Announcement>[];

    final received = <String>{};
    final subs = <StreamSubscription<dynamic>>[];

    void emit() {
      if (received.length < 6) return;
      controller.add(
        computeAdminDashboard(
          students: students,
          todayRecords: todayRecords,
          classes: classes,
          users: users,
          homeworkItems: homeworkItems,
          announcements: announcementItems,
          today: today,
        ),
      );
    }

    void listen<T>(String key, Stream<List<T>> stream, void Function(List<T>) onData) {
      subs.add(
        stream.listen((items) {
          received.add(key);
          onData(items);
          emit();
        }, onError: controller.addError),
      );
    }

    listen('students', roster.watchStudents(), (items) => students = items);
    listen(
      'attendance',
      attendance.watchForDate(dateKey),
      (items) => todayRecords = items,
    );
    listen('classes', roster.watchClasses(), (items) => classes = items);
    listen('users', roster.watchUsers(), (items) => users = items);
    listen('homework', homework.watch(), (items) => homeworkItems = items);
    listen(
      'announcements',
      announcements.watch(),
      (items) => announcementItems = items,
    );

    controller.onCancel = () {
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
    };
  });
}
