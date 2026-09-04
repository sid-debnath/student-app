import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).valueOrNull?.role ?? UserRole.viewer;
    final items = switch (role) {
      UserRole.admin => const [
        _Item('Users', '/users', Icons.manage_accounts_outlined),
        _Item('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Item('Exams & reports', '/marks', Icons.grade_outlined),
        _Item('PTM', '/ptm', Icons.event_outlined),
        _Item('Homework', '/homework', Icons.menu_book_outlined),
        _Item('Attendance', '/attendance', Icons.fact_check_outlined),
      ],
      UserRole.teacher || UserRole.floorIncharge => const [
        _Item('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Item('Marks', '/marks', Icons.grade_outlined),
        _Item('Announcements', '/announcements', Icons.campaign_outlined),
        _Item('PTM', '/ptm', Icons.event_outlined),
      ],
      UserRole.viewer => const [
        _Item('Account Details', '/account', Icons.person_outline),
        _Item('Timetable', '/timetable', Icons.calendar_view_week_outlined),
        _Item('Marks & reports', '/marks', Icons.grade_outlined),
        _Item('Announcements', '/announcements', Icons.campaign_outlined),
        _Item('PTM', '/ptm', Icons.event_outlined),
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(item.path),
            ),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
