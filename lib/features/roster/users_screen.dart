import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';
import '../../widgets/class_chips.dart';
import '../../widgets/class_dropdown.dart';

enum _InviteKind { teacher, student, parent, admin }

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
    super.dispose();
  }

  UserRole get _authRole => switch (_kind) {
    _InviteKind.teacher => UserRole.teacher,
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

    setState(() => _busy = true);
    try {
      var studentIds = <String>[];
      var classIds = <String>[];
      if (_kind == _InviteKind.teacher) {
        classIds = _selectedClassIds.toList();
      } else if (_kind == _InviteKind.parent) {
        studentIds = _selectedStudentIds.toList();
      } else if (_kind == _InviteKind.student) {
        final classId = await roster.selectedOrFirstClassId(_studentClassId);
        if (classId == null) {
          throw StateError('Add a class on Roster first, then add students.');
        }
        studentIds = [
          await roster.upsertStudent(
            Student(
              id: '',
              name: name,
              classId: classId,
              roll: _roll.text.trim(),
            ),
          ),
        ];
        classIds = [classId];
      }

      final uid = await ref.read(authRepositoryProvider).createInstitutionUser(
        email: email,
        password: password,
        displayName: name,
        role: _authRole,
        classIds: classIds,
        studentIds: studentIds,
      );
      if (uid != null) {
        for (final studentId in studentIds) {
          await roster.linkViewer(studentId: studentId, viewerId: uid);
        }
      }
      if (!mounted) return;
      _email.clear();
      _password.clear();
      _name.clear();
      _roll.clear();
      setState(() {
        _selectedClassIds.clear();
        _selectedStudentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _kind == _InviteKind.student ? 'Student added' : 'User created',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _userSubtitle(AppUser user, List<AcademicClass> classes) {
    final classLabels = [
      for (final academicClass in classes)
        if (user.classIds.contains(academicClass.id)) academicClass.label,
    ];
    final extra = user.isTeacher && classLabels.isNotEmpty
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
            decoration: const InputDecoration(labelText: 'Temporary password'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_InviteKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: _InviteKind.teacher, child: Text('Teacher')),
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
                if (_kind == _InviteKind.teacher) {
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
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runGuarded(
                                context,
                                () => roster.deleteStudent(student.id),
                              ),
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
