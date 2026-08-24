import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';
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
        },
      ),
    );
  }
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
