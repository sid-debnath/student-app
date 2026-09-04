import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/auth_repository.dart';
import '../../models/academic_class.dart';
import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_chips.dart';
import '../../widgets/class_dropdown.dart';

enum _InviteKind { teacher, floorIncharge, student, parent, admin }

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _roll = TextEditingController();
  final _alternativePhone = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherPhone = TextEditingController();
  var _kind = _InviteKind.teacher;
  var _busy = false;
  final _selectedClassIds = <String>{};
  final _selectedStudentIds = <String>{};
  String? _studentClassId;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _roll.dispose();
    _alternativePhone.dispose();
    _fatherPhone.dispose();
    _motherPhone.dispose();
    super.dispose();
  }

  UserRole get _authRole => switch (_kind) {
    _InviteKind.teacher => UserRole.teacher,
    _InviteKind.floorIncharge => UserRole.floorIncharge,
    _InviteKind.admin => UserRole.admin,
    _InviteKind.student || _InviteKind.parent => UserRole.viewer,
  };

  Future<void> _create() async {
    final roster = ref.read(rosterRepositoryProvider);
    if (roster == null) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showError(context, 'Name, email, and password are required.');
      return;
    }
    if (_kind == _InviteKind.parent && _selectedStudentIds.isEmpty) {
      showError(context, 'Choose at least one student for this parent.');
      return;
    }
    if (_kind == _InviteKind.floorIncharge && _selectedClassIds.isEmpty) {
      showError(context, 'Choose at least one class for this floor in-charge.');
      return;
    }
    final alternativePhone = _alternativePhone.text.trim();
    final fatherPhone = _fatherPhone.text.trim();
    final motherPhone = _motherPhone.text.trim();
    if (_kind == _InviteKind.parent) {
      if (fatherPhone.isEmpty || motherPhone.isEmpty) {
        showError(
          context,
          'Father Phone and Mother Phone are required.',
        );
        return;
      }
    }

    setState(() => _busy = true);
    String? createdStudentId;
    try {
      var studentIds = <String>[];
      var classIds = <String>[];
      String? studentClassId;
      String studentRoll = '';
      ViewerAccountType? viewerAccountType;
      if (_kind == _InviteKind.teacher || _kind == _InviteKind.floorIncharge) {
        classIds = _selectedClassIds.toList();
      } else if (_kind == _InviteKind.parent) {
        studentIds = _selectedStudentIds.toList();
        viewerAccountType = ViewerAccountType.parent;
      } else if (_kind == _InviteKind.student) {
        studentClassId = await roster.selectedOrFirstClassId(_studentClassId);
        if (studentClassId == null) {
          throw StateError('Add a class on Roster first, then add students.');
        }
        studentRoll = _roll.text.trim();
        classIds = [studentClassId];
        viewerAccountType = ViewerAccountType.student;
      }

      final uid = await _createUserAccount(
        email: email,
        password: password,
        name: name,
        classIds: classIds,
        studentIds: studentIds,
        fatherPhone: _kind == _InviteKind.parent ? fatherPhone : '',
        motherPhone: _kind == _InviteKind.parent ? motherPhone : '',
        alternativePhone: _kind == _InviteKind.parent ? alternativePhone : '',
        viewerAccountType: viewerAccountType,
      );

      if (_kind == _InviteKind.student && studentClassId != null && uid != null) {
        createdStudentId = await roster.upsertStudent(
          Student(
            id: '',
            name: name,
            classId: studentClassId,
            roll: studentRoll,
          ),
        );
        studentIds = [createdStudentId];
        await roster.linkViewer(studentId: createdStudentId, viewerId: uid);
      } else if (uid != null) {
        for (final studentId in studentIds) {
          await roster.linkViewer(studentId: studentId, viewerId: uid);
        }
      }
      if (!mounted) return;
      _email.clear();
      _password.clear();
      _name.clear();
      _roll.clear();
      _alternativePhone.clear();
      _fatherPhone.clear();
      _motherPhone.clear();
      setState(() {
        _selectedClassIds.clear();
        _selectedStudentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _kind == _InviteKind.student
                ? 'Student added'
                : _kind == _InviteKind.floorIncharge
                    ? 'Floor In-Charge created'
                    : 'User created',
          ),
        ),
      );
    } catch (error) {
      if (createdStudentId != null) {
        try {
          await roster.deleteStudent(createdStudentId);
        } catch (_) {}
      }
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _createUserAccount({
    required String email,
    required String password,
    required String name,
    required List<String> classIds,
    required List<String> studentIds,
    String fatherPhone = '',
    String motherPhone = '',
    String alternativePhone = '',
    ViewerAccountType? viewerAccountType,
    String? previousPassword,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    try {
      return await auth.createInstitutionUser(
        email: email,
        password: password,
        displayName: name,
        role: _authRole,
        classIds: classIds,
        studentIds: studentIds,
        fatherPhone: fatherPhone,
        motherPhone: motherPhone,
        alternativePhone: alternativePhone,
        viewerAccountType: viewerAccountType,
        previousPassword: previousPassword,
      );
    } on AuthReenrollPasswordNeeded catch (needed) {
      if (!mounted) return null;
      final previous = await _askPreviousPassword(needed.email);
      if (previous == null || previous.isEmpty) {
        throw StateError(
          'Could not re-enroll $email. Enter the current login password, '
          'or delete that Auth user in Firebase Console → Authentication.',
        );
      }
      return auth.createInstitutionUser(
        email: email,
        password: password,
        displayName: name,
        role: _authRole,
        classIds: classIds,
        studentIds: studentIds,
        fatherPhone: fatherPhone,
        motherPhone: motherPhone,
        alternativePhone: alternativePhone,
        viewerAccountType: viewerAccountType,
        previousPassword: previous,
      );
    }
  }

  Future<String?> _askPreviousPassword(String email) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PreviousPasswordDialog(email: email),
    );
  }

  Future<void> _editUser(AppUser user) async {
    final roster = ref.read(rosterRepositoryProvider);
    if (roster == null) return;
    final classes = await roster.watchClasses().first;
    final students = await roster.watchStudents().first;
    if (!mounted) return;
    final draft = await showDialog<_UserDraft>(
      context: context,
      builder: (context) => _UserEditDialog(
        user: user,
        classes: classes,
        students: students,
      ),
    );
    if (!mounted || draft == null) return;
    await runGuarded(context, () async {
      await roster.updateUser(
        user: user,
        displayName: draft.displayName,
        role: draft.role,
        classIds: draft.classIds,
        studentIds: draft.studentIds,
        fatherPhone: draft.fatherPhone,
        motherPhone: draft.motherPhone,
        alternativePhone: draft.alternativePhone,
        viewerAccountType: draft.viewerAccountType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated')),
      );
    });
  }

  Future<void> _deleteUser(AppUser user) async {
    final roster = ref.read(rosterRepositoryProvider);
    final actorUid = ref.read(sessionProvider).valueOrNull?.id;
    if (roster == null || actorUid == null) return;
    
       
    final result = await showDialog<_DeleteUserResult>(
      context: context,
      builder: (context) => _DeleteUserDialog(user: user),
    );
    if (result == null || !result.confirmed || !mounted) return;
    await runGuarded(context, () async {
      await ref.read(authRepositoryProvider).deleteInstitutionAuthUser(
        uid: user.id,
        email: user.email,
        passwordForAuthCleanup: result.passwordForAuthCleanup,
      );
      await roster.deleteUser(user, actorUid: actorUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account deleted (login, profile, and related student data).',
          ),
        ),
      );
    });
  }

  Future<void> _deleteStudent(Student student) async {
    final roster = ref.read(rosterRepositoryProvider);
    if (roster == null) return;
    final exclusiveLogins = await roster.prepareStudentAccountDeletion(student.id);
    if (!mounted) return;
    final result = await showDialog<_DeleteUserResult>(
      context: context,
      builder: (context) => _DeleteStudentDialog(
        student: student,
        exclusiveLogins: exclusiveLogins,
      ),
    );
    if (result == null || !result.confirmed || !mounted) return;
    await runGuarded(context, () async {
      final auth = ref.read(authRepositoryProvider);
      for (final login in exclusiveLogins) {
        await auth.deleteInstitutionAuthUser(
          uid: login.id,
          email: login.email,
          passwordForAuthCleanup: result.passwordForAuthCleanup,
        );
      }
      await roster.deleteStudentCompletely(student.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student and linked login removed completely.'),
        ),
      );
    });
  }

  Future<void> _editStudent(Student student) async {
    final roster = ref.read(rosterRepositoryProvider);
    if (roster == null) return;
    final classes = await roster.watchClasses().first;
    if (!mounted) return;
    final draft = await showDialog<_StudentDraft>(
      context: context,
      builder: (context) => _StudentEditDialog(
        student: student,
        classes: classes,
      ),
    );
    if (!mounted || draft == null) return;
    await runGuarded(context, () async {
      await roster.upsertStudent(
        Student(
          id: student.id,
          name: draft.name,
          classId: draft.classId,
          roll: draft.roll,
          viewerUids: student.viewerUids,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student updated')),
      );
    });
  }

  String _userSubtitle(AppUser user, List<AcademicClass> classes) {
    final classLabels = [
      for (final academicClass in classes)
        if (user.classIds.contains(academicClass.id)) academicClass.label,
    ];
    final extra = (user.isTeacher || user.isFloorIncharge) && classLabels.isNotEmpty
        ? ' · ${classLabels.join(', ')}'
        : '';
    return '${user.role.name} · ${user.email}$extra';
  }

  String _studentSubtitle(Student student, List<AcademicClass> classes) {
    final classLabel = classes
        .where((item) => item.id == student.classId)
        .map((item) => item.label)
        .firstOrNull;
    final roll = student.roll.isEmpty ? '' : ' · Roll ${student.roll}';
    return '${classLabel ?? 'No class'}$roll';
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 8),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Default password',
              helperText:
                  'Staff and student accounts must change this on first sign-in. '
                  'After a permanent delete, recreating the same email is a new account.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_InviteKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: _InviteKind.teacher, child: Text('Teacher')),
              DropdownMenuItem(value: _InviteKind.floorIncharge, child: Text('Floor In-Charge')),
              DropdownMenuItem(value: _InviteKind.student, child: Text('Student')),
              DropdownMenuItem(value: _InviteKind.parent, child: Text('Parent')),
              DropdownMenuItem(value: _InviteKind.admin, child: Text('Admin')),
            ],
            onChanged: (value) => setState(() => _kind = value ?? _InviteKind.teacher),
          ),
          const SizedBox(height: 12),
          if (roster == null)
            const LinearProgressIndicator()
          else
            StreamBuilder<List<AcademicClass>>(
              stream: roster.watchClasses(),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                if (_kind == _InviteKind.teacher || _kind == _InviteKind.floorIncharge) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Classes', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ClassChips(
                        classes: classes,
                        selectedIds: _selectedClassIds,
                        onChanged: (ids) => setState(() {
                          _selectedClassIds
                            ..clear()
                            ..addAll(ids);
                        }),
                      ),
                    ],
                  );
                }
                if (_kind == _InviteKind.student) {
                  final classId = classes.any((item) => item.id == _studentClassId)
                      ? _studentClassId
                      : (classes.isEmpty ? null : classes.first.id);
                  return Column(
                    children: [
                      ClassDropdown(
                        key: ValueKey('invite-class-$classId'),
                        classes: classes,
                        value: classId,
                        onChanged: (value) => setState(() => _studentClassId = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _roll,
                        decoration: const InputDecoration(labelText: 'Roll number'),
                      ),
                    ],
                  );
                }
                if (_kind == _InviteKind.parent) {
                  return StreamBuilder<List<Student>>(
                    stream: roster.watchStudents(),
                    builder: (context, studentSnap) {
                      final students = studentSnap.data ?? [];
                      if (students.isEmpty) {
                        return const Text('Add students first, then invite a parent.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _fatherPhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Father Phone *',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _motherPhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mother Phone *',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _alternativePhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Alternative Phone (optional)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Students', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final student in students)
                                FilterChip(
                                  label: Text(
                                    '${student.name} (${_studentSubtitle(student, classes)})',
                                  ),
                                  selected: _selectedStudentIds.contains(student.id),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedStudentIds.add(student.id);
                                      } else {
                                        _selectedStudentIds.remove(student.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(_kind == _InviteKind.student ? 'Add student' : 'Create account'),
          ),
          const SizedBox(height: 24),
          Text('Students', style: Theme.of(context).textTheme.titleMedium),
          if (roster == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            StreamBuilder<List<AcademicClass>>(
              stream: roster.watchClasses(),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                return StreamBuilder<List<Student>>(
                  stream: roster.watchStudents(),
                  builder: (context, snapshot) {
                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No students yet. Choose Student above to add one.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final student in students)
                          ListTile(
                            title: Text(student.name),
                            subtitle: Text(_studentSubtitle(student, classes)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit student',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editStudent(student),
                                ),
                                IconButton(
                                  tooltip: 'Delete student',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteStudent(student),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 24),
          Text('Existing users', style: Theme.of(context).textTheme.titleMedium),
          if (roster == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            StreamBuilder<List<AcademicClass>>(
              stream: roster.watchClasses(),
              builder: (context, classSnap) {
                final classes = classSnap.data ?? [];
                return StreamBuilder<List<AppUser>>(
                  stream: roster.watchUsers(),
                  builder: (context, snapshot) {
                    final users = snapshot.data ?? [];
                    return Column(
                      children: [
                        for (final user in users)
                          ListTile(
                            title: Text(user.displayName.isEmpty ? user.email : user.displayName),
                            subtitle: Text(_userSubtitle(user, classes)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit user',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editUser(user),
                                ),
                                IconButton(
                                  tooltip: 'Delete user',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteUser(user),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PreviousPasswordDialog extends StatefulWidget {
  const _PreviousPasswordDialog({required this.email});

  final String email;

  @override
  State<_PreviousPasswordDialog> createState() => _PreviousPasswordDialogState();
}

class _PreviousPasswordDialogState extends State<_PreviousPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Email already has a login'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.email} was deleted from the app before, but Firebase Auth '
            'still has that login (often with an older password). Enter '
            'the current password so it can be reset to the new temporary '
            'password.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(context, _password.text),
            decoration: const InputDecoration(
              labelText: 'Current password for this email',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _password.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _DeleteUserResult {
  const _DeleteUserResult({
    required this.confirmed,
    this.passwordForAuthCleanup,
  });

  final bool confirmed;
  final String? passwordForAuthCleanup;
}

class _DeleteUserDialog extends StatefulWidget {
  const _DeleteUserDialog({required this.user});

  final AppUser user;

  @override
  State<_DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<_DeleteUserDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.user.displayName.isEmpty
        ? widget.user.email
        : widget.user.displayName;
    return AlertDialog(
      title: const Text('Delete account permanently?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes $label including Firebase login, '
            'email credentials, institution profile, and related student data. '
            'Recreating this email later creates a brand-new account.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Current password for ${widget.user.email}',
              helperText: 'Required to remove the Firebase Authentication user.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _password.text;
            if (text.isEmpty) return;
            Navigator.pop(
              context,
              _DeleteUserResult(
                confirmed: true,
                passwordForAuthCleanup: text,
              ),
            );
          },
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _DeleteStudentDialog extends StatefulWidget {
  const _DeleteStudentDialog({
    required this.student,
    required this.exclusiveLogins,
  });

  final Student student;
  final List<AppUser> exclusiveLogins;

  @override
  State<_DeleteStudentDialog> createState() => _DeleteStudentDialogState();
}

class _DeleteStudentDialogState extends State<_DeleteStudentDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logins = widget.exclusiveLogins;
    if (logins.length > 1) {
      return AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          '${widget.student.name} has multiple linked logins. '
          'Delete each login under Existing users first, then delete the student.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }
    final login = logins.firstOrNull;
    return AlertDialog(
      title: const Text('Delete student permanently?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This removes ${widget.student.name} and related attendance, marks, '
            'report cards, and PTM data.'
            '${login == null ? '' : ' It also permanently deletes the linked '
                'login ${login.email} so the email can be recreated as a new account.'}',
          ),
          if (login != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Current password for ${login.email}',
                helperText: 'Required to delete Firebase Authentication.',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (login != null && _password.text.isEmpty) return;
            Navigator.pop(
              context,
              _DeleteUserResult(
                confirmed: true,
                passwordForAuthCleanup:
                    login == null ? null : _password.text,
              ),
            );
          },
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _UserDraft {
  const _UserDraft({
    required this.displayName,
    required this.role,
    required this.classIds,
    required this.studentIds,
    this.fatherPhone = '',
    this.motherPhone = '',
    this.alternativePhone = '',
    this.viewerAccountType,
  });

  final String displayName;
  final UserRole role;
  final List<String> classIds;
  final List<String> studentIds;
  final String fatherPhone;
  final String motherPhone;
  final String alternativePhone;
  final ViewerAccountType? viewerAccountType;
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({
    required this.user,
    required this.classes,
    required this.students,
  });

  final AppUser user;
  final List<AcademicClass> classes;
  final List<Student> students;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _alternativePhone;
  late final TextEditingController _fatherPhone;
  late final TextEditingController _motherPhone;
  late UserRole _role;
  late Set<String> _classIds;
  late Set<String> _studentIds;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _alternativePhone = TextEditingController(text: widget.user.alternativePhone);
    _fatherPhone = TextEditingController(text: widget.user.fatherPhone);
    _motherPhone = TextEditingController(text: widget.user.motherPhone);
    _role = widget.user.role;
    _classIds = {...widget.user.classIds};
    _studentIds = {...widget.user.studentIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _alternativePhone.dispose();
    _fatherPhone.dispose();
    _motherPhone.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final alternativePhone = _alternativePhone.text.trim();
    final fatherPhone = _fatherPhone.text.trim();
    final motherPhone = _motherPhone.text.trim();
    if (_role == UserRole.viewer &&
        (widget.user.isParentAccount ||
            fatherPhone.isNotEmpty ||
            motherPhone.isNotEmpty ||
            alternativePhone.isNotEmpty)) {
      if (fatherPhone.isEmpty || motherPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Father Phone and Mother Phone are required for parents.',
            ),
          ),
        );
        return;
      }
    }
    Navigator.pop(
      context,
      _UserDraft(
        displayName: name,
        role: _role,
        classIds: _classIds.toList(),
        studentIds: _studentIds.toList(),
        fatherPhone: _role == UserRole.viewer ? fatherPhone : '',
        motherPhone: _role == UserRole.viewer ? motherPhone : '',
        alternativePhone: _role == UserRole.viewer ? alternativePhone : '',
        viewerAccountType: _role == UserRole.viewer
            ? (fatherPhone.isNotEmpty || motherPhone.isNotEmpty
                ? ViewerAccountType.parent
                : (widget.user.viewerAccountType ?? ViewerAccountType.student))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit user'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.email, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
                  DropdownMenuItem(value: UserRole.floorIncharge, child: Text('Floor In-Charge')),
                  DropdownMenuItem(value: UserRole.viewer, child: Text('Student / parent')),
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              if (_role == UserRole.teacher || _role == UserRole.floorIncharge) ...[
                const SizedBox(height: 16),
                Text('Classes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ClassChips(
                  classes: widget.classes,
                  selectedIds: _classIds,
                  onChanged: (ids) => setState(() {
                    _classIds
                      ..clear()
                      ..addAll(ids);
                  }),
                ),
              ],
              if (_role == UserRole.viewer) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _fatherPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Father Phone',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _motherPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mother Phone',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _alternativePhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Alternative Phone (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Linked students', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (widget.students.isEmpty)
                  const Text('No students in the roster yet.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final student in widget.students)
                        FilterChip(
                          label: Text(student.name),
                          selected: _studentIds.contains(student.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _studentIds.add(student.id);
                              } else {
                                _studentIds.remove(student.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _StudentDraft {
  const _StudentDraft({
    required this.name,
    required this.classId,
    required this.roll,
  });

  final String name;
  final String classId;
  final String roll;
}

class _StudentEditDialog extends StatefulWidget {
  const _StudentEditDialog({
    required this.student,
    required this.classes,
  });

  final Student student;
  final List<AcademicClass> classes;

  @override
  State<_StudentEditDialog> createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<_StudentEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _roll;
  late String? _classId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.student.name);
    _roll = TextEditingController(text: widget.student.roll);
    _classId = widget.classes.any((item) => item.id == widget.student.classId)
        ? widget.student.classId
        : widget.classes.firstOrNull?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _roll.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final classId = _classId;
    if (name.isEmpty || classId == null) return;
    Navigator.pop(
      context,
      _StudentDraft(name: name, classId: classId, roll: _roll.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit student'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            ClassDropdown(
              classes: widget.classes,
              value: _classId,
              onChanged: (value) => setState(() => _classId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roll,
              decoration: const InputDecoration(labelText: 'Roll number'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
