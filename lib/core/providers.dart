import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/announcement_repository.dart';
import '../data/attendance_repository.dart';
import '../data/auth_repository.dart';
import '../data/homework_repository.dart';
import '../data/marks_repository.dart';
import '../data/ptm_repository.dart';
import '../data/roster_repository.dart';
import '../data/timetable_repository.dart';
import '../models/app_user.dart';

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

final schoolIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider).valueOrNull?.schoolId;
});

final rosterRepositoryProvider = Provider<RosterRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : RosterRepository(schoolId);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : AttendanceRepository(schoolId);
});

final homeworkRepositoryProvider = Provider<HomeworkRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : HomeworkRepository(schoolId);
});

final timetableRepositoryProvider = Provider<TimetableRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : TimetableRepository(schoolId);
});

final marksRepositoryProvider = Provider<MarksRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : MarksRepository(schoolId);
});

final announcementRepositoryProvider = Provider<AnnouncementRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : AnnouncementRepository(schoolId);
});

final ptmRepositoryProvider = Provider<PtmRepository?>((ref) {
  final schoolId = ref.watch(schoolIdProvider);
  return schoolId == null ? null : PtmRepository(schoolId);
});
