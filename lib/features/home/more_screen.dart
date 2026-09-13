import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/keyboard_shortcuts.dart';
import '../../core/providers.dart';
import '../../models/app_user.dart';
import '../../models/user_preferences.dart';
import '../../widgets/async_body.dart';

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

    final selectedTheme = ref.watch(themeProvider);
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(selectedTheme.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(ref, context, selectedTheme.id),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: const Text('Keyboard shortcuts'),
            onTap: () => showKeyboardShortcutsDialog(context, role),
          ),
        ],
      ),
    );
  }

  void _pickTheme(WidgetRef ref, BuildContext context, String currentId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<String>(
            groupValue: currentId,
            onChanged: (id) {
              Navigator.pop(dialogContext);
              if (id == null || id == currentId) return;
              _saveTheme(ref, context, id);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final theme in appThemes)
                  RadioListTile<String>(
                    value: theme.id,
                    title: Text(theme.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveTheme(WidgetRef ref, BuildContext context, String themeId) {
    guard(
      context,
      () => ref.read(authRepositoryProvider).updatePreference(
        UserPreferences.themeIdKey,
        themeId,
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
