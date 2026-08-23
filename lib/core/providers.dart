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
import '../models/institution.dart';
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

final ptmRepositoryProvider = Provider<PtmRepository?>((ref) {
  final institutionId = ref.watch(institutionIdProvider);
  return institutionId == null ? null : PtmRepository(institutionId);
});
