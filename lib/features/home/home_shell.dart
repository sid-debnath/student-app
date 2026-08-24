import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/app_user.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final tabs = _tabsFor(profile?.role ?? UserRole.viewer);
    var index = tabs.indexWhere((tab) => tab.path == location);
    if (index < 0) {
      index = tabs.indexWhere((tab) => tab.path == '/more');
    }

    ref.listen(sessionProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) return;
      ref.read(authRepositoryProvider).saveFcmToken(user);
      final selected = ref.read(selectedStudentIdProvider);
      if (selected == null && user.studentIds.isNotEmpty) {
        ref.read(selectedStudentIdProvider.notifier).select(user.studentIds.first);
      }
    });

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (value) => context.go(tabs[value].path),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

List<_Tab> _tabsFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        _Tab('/', 'Home', Icons.home_outlined),
        _Tab('/roster', 'Roster', Icons.groups_outlined),
        _Tab('/announcements', 'News', Icons.campaign_outlined),
        _Tab('/more', 'More', Icons.grid_view_outlined),
      ];
    case UserRole.teacher:
      return const [
        _Tab('/', 'Home', Icons.home_outlined),
        _Tab('/homework', 'Homework', Icons.menu_book_outlined),
        _Tab('/announcements', 'News', Icons.campaign_outlined),
        _Tab('/more', 'More', Icons.grid_view_outlined),
      ];
    case UserRole.viewer:
      return const [
        _Tab('/', 'Home', Icons.home_outlined),
        _Tab('/attendance', 'Attendance', Icons.fact_check_outlined),
        _Tab('/homework', 'Homework', Icons.menu_book_outlined),
        _Tab('/more', 'More', Icons.grid_view_outlined),
      ];
  }
}
