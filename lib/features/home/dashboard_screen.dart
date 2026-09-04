import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/academic_class.dart';
import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../widgets/async_body.dart';
import '../../widgets/brand_logo.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            BrandLogo(height: 28, brand: brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text(brand.displayName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AsyncBody(
        value: ref.watch(sessionProvider),
        builder: (user) {
          if (user == null) {
            return const Center(child: Text('Loading profile…'));
          }
          if (user.isParentAccount) {
            return _ParentDashboard(user: user);
          }
          if (user.isStudentAccount) {
            return _StudentDashboard(user: user);
          }
          return _StaffDashboard(user: user);
        },
      ),
    );
  }
}

class _StaffDashboard extends StatelessWidget {
  const _StaffDashboard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final actions = _actions(user.role);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(user.displayName.isEmpty ? user.email : user.displayName),
            subtitle: Text('${user.role.name} · ${user.email}'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              ActionChip(
                avatar: Icon(action.icon, size: 18),
                label: Text(action.label),
                onPressed: () => context.go(action.path),
              ),
          ],
        ),
      ],
    );
  }
}

class _ParentDashboard extends ConsumerWidget {
  const _ParentDashboard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterRepositoryProvider);
    final theme = Theme.of(context);
    final parentName =
        user.displayName.isEmpty ? user.email : user.displayName;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome, Mr. $parentName',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: const Text('Account Details'),
          subtitle: const Text('Phone numbers and profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/account'),
        ),
        const Divider(),
        Text('Linked children', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (roster == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          )
        else if (user.studentIds.isEmpty)
          Text(
            'No children linked yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          StreamBuilder<List<AcademicClass>>(
            stream: roster.watchClasses(),
            builder: (context, classSnap) {
              final classes = classSnap.data ?? const <AcademicClass>[];
              return StreamBuilder<List<Student>>(
                stream: roster.watchStudentsByIds(user.studentIds),
                builder: (context, studentSnap) {
                  if (studentSnap.hasError) {
                    return Text(
                      'Could not load linked children.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    );
                  }
                  if (!studentSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final children = studentSnap.data!;
                  if (children.isEmpty) {
                    return Text(
                      'No children linked yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final child in children)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.school_outlined),
                          title: Text(child.name),
                          subtitle: Text(_studentSubtitle(child, classes)),
                          onTap: () {
                            ref
                                .read(selectedStudentIdProvider.notifier)
                                .select(child.id);
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
        const SizedBox(height: 24),
        Text('Quick actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in _actions(UserRole.viewer))
              ActionChip(
                avatar: Icon(action.icon, size: 18),
                label: Text(action.label),
                onPressed: () => context.go(action.path),
              ),
          ],
        ),
      ],
    );
  }
}

class _StudentDashboard extends ConsumerWidget {
  const _StudentDashboard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterRepositoryProvider);
    final theme = Theme.of(context);
    final fallbackName =
        user.displayName.isEmpty ? user.email : user.displayName;
    final studentId = ref.watch(selectedStudentIdProvider) ??
        (user.studentIds.isEmpty ? null : user.studentIds.first);

    Widget welcome(String name) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, $name',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text('Quick actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in _actions(UserRole.viewer))
                ActionChip(
                  avatar: Icon(action.icon, size: 18),
                  label: Text(action.label),
                  onPressed: () => context.go(action.path),
                ),
            ],
          ),
        ],
      );
    }

    if (roster == null || studentId == null) {
      return welcome(fallbackName);
    }

    return StreamBuilder<Student?>(
      stream: roster.watchStudent(studentId),
      builder: (context, snapshot) {
        final studentName = snapshot.data?.name.trim();
        final name = (studentName != null && studentName.isNotEmpty)
            ? studentName
            : fallbackName;
        return welcome(name);
      },
    );
  }
}

String _studentSubtitle(Student student, List<AcademicClass> classes) {
  final classLabel = classes
      .where((item) => item.id == student.classId)
      .map((item) => item.label)
      .firstOrNull;
  final roll = student.roll.isEmpty ? '' : ' · Roll ${student.roll}';
  return '${classLabel ?? 'No class'}$roll';
}

class _Action {
  const _Action(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

List<_Action> _actions(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        _Action('Roster', '/roster', Icons.groups_outlined),
        _Action('Invite users', '/users', Icons.person_add_outlined),
        _Action('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Action('Announcements', '/announcements', Icons.campaign_outlined),
        _Action('Exams & reports', '/marks', Icons.grade_outlined),
        _Action('PTM', '/ptm', Icons.event_outlined),
      ];
    case UserRole.teacher:
      return const [
        _Action('Attendance', '/attendance', Icons.fact_check_outlined),
        _Action('Homework', '/homework', Icons.menu_book_outlined),
        _Action('Marks', '/marks', Icons.grade_outlined),
        _Action('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Action('Announcements', '/announcements', Icons.campaign_outlined),
        _Action('PTM slots', '/ptm', Icons.event_outlined),
      ];
    case UserRole.floorIncharge:
      return const [
        _Action('Attendance', '/attendance', Icons.fact_check_outlined),
        _Action('Homework', '/homework', Icons.menu_book_outlined),
        _Action('Marks', '/marks', Icons.grade_outlined),
        _Action('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Action('Announcements', '/announcements', Icons.campaign_outlined),
        _Action('PTM slots', '/ptm', Icons.event_outlined),
      ];
    case UserRole.viewer:
      return const [
        _Action('Attendance', '/attendance', Icons.fact_check_outlined),
        _Action('Homework', '/homework', Icons.menu_book_outlined),
        _Action('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Action('Report card', '/marks', Icons.grade_outlined),
        _Action('Announcements', '/announcements', Icons.campaign_outlined),
        _Action('Book PTM', '/ptm', Icons.event_outlined),
      ];
  }
}
