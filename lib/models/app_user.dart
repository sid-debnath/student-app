enum UserRole { admin, teacher, viewer }

UserRole userRoleFromString(String? value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.viewer,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.schoolId,
    this.studentIds = const [],
    this.classIds = const [],
    this.fcmToken,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String schoolId;
  final List<String> studentIds;
  final List<String> classIds;
  final String? fcmToken;

  bool get isAdmin => role == UserRole.admin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isViewer => role == UserRole.viewer;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: userRoleFromString(data['role'] as String?),
      schoolId: data['schoolId'] as String? ?? 'default',
      studentIds: List<String>.from(data['studentIds'] as List? ?? const []),
      classIds: List<String>.from(data['classIds'] as List? ?? const []),
      fcmToken: data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'schoolId': schoolId,
    'studentIds': studentIds,
    'classIds': classIds,
    if (fcmToken != null) 'fcmToken': fcmToken,
  };
}
