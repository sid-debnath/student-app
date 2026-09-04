enum UserRole { admin, teacher, floorIncharge, viewer }

UserRole userRoleFromString(String? value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.viewer,
  );
}

/// Distinguishes parent vs student logins that share [UserRole.viewer].
enum ViewerAccountType { parent, student }

ViewerAccountType? viewerAccountTypeFromString(String? value) {
  return switch (value) {
    'parent' => ViewerAccountType.parent,
    'student' => ViewerAccountType.student,
    _ => null,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.institutionId,
    this.studentIds = const [],
    this.classIds = const [],
    this.fatherPhone = '',
    this.motherPhone = '',
    this.alternativePhone = '',
    this.viewerAccountType,
    this.fcmToken,
    this.mustChangePassword,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String institutionId;
  final List<String> studentIds;
  final List<String> classIds;

  /// Parent enrollment: Father Phone (required for parents).
  final String fatherPhone;

  /// Parent enrollment: Mother Phone (required for parents).
  final String motherPhone;

  /// Parent enrollment: Alternative Phone (optional).
  final String alternativePhone;

  /// Explicit parent/student tag when set on the profile.
  final ViewerAccountType? viewerAccountType;

  final String? fcmToken;

  /// `true` / `false` when set on the profile; `null` for legacy docs created
  /// before the first-login password-change field existed.
  final bool? mustChangePassword;

  bool get isAdmin => role == UserRole.admin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isFloorIncharge => role == UserRole.floorIncharge;
  bool get isStaff => isTeacher || isFloorIncharge;
  bool get isViewer => role == UserRole.viewer;

  bool get hasParentPhones =>
      fatherPhone.isNotEmpty ||
      motherPhone.isNotEmpty ||
      alternativePhone.isNotEmpty;

  /// Parent login (vs student viewer). Prefers stored [viewerAccountType].
  bool get isParentAccount {
    if (!isViewer) return false;
    if (viewerAccountType == ViewerAccountType.parent) return true;
    if (viewerAccountType == ViewerAccountType.student) return false;
    return hasParentPhones;
  }

  bool get isStudentAccount => isViewer && !isParentAccount;

  /// Teachers and viewers must change a temp password until the profile
  /// explicitly records `mustChangePassword: false`.
  ///
  /// Missing field (legacy enrollments) is treated as still required so older
  /// student accounts behave like newly created ones.
  bool get requiresFirstLoginPasswordChange =>
      (isTeacher || isFloorIncharge || isViewer) && mustChangePassword != false;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    final fatherPhone = (data['fatherPhone'] as String?)?.trim().isNotEmpty == true
        ? (data['fatherPhone'] as String).trim()
        : (data['fatherMobile'] as String? ?? '').trim();
    final motherPhone = (data['motherPhone'] as String?)?.trim().isNotEmpty == true
        ? (data['motherPhone'] as String).trim()
        : (data['motherMobile'] as String? ?? '').trim();
    final alternativePhone =
        (data['alternativePhone'] as String?)?.trim().isNotEmpty == true
        ? (data['alternativePhone'] as String).trim()
        : (data['primaryMobile'] as String? ?? '').trim();

    return AppUser(
      id: id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: userRoleFromString(data['role'] as String?),
      institutionId: data['institutionId'] as String? ?? 'default',
      studentIds: List<String>.from(data['studentIds'] as List? ?? const []),
      classIds: List<String>.from(data['classIds'] as List? ?? const []),
      fatherPhone: fatherPhone,
      motherPhone: motherPhone,
      alternativePhone: alternativePhone,
      viewerAccountType: viewerAccountTypeFromString(
        data['viewerAccountType'] as String?,
      ),
      fcmToken: data['fcmToken'] as String?,
      mustChangePassword: data.containsKey('mustChangePassword')
          ? data['mustChangePassword'] == true
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'institutionId': institutionId,
    'studentIds': studentIds,
    'classIds': classIds,
    'fatherPhone': fatherPhone,
    'motherPhone': motherPhone,
    'alternativePhone': alternativePhone,
    if (viewerAccountType != null)
      'viewerAccountType': viewerAccountType!.name,
    if (mustChangePassword != null) 'mustChangePassword': mustChangePassword,
    if (fcmToken != null) 'fcmToken': fcmToken,
  };
}
