import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'providers.dart';
import 'router.dart';

/// A keyboard shortcut registered globally and listed in the help dialog.
class AppShortcut {
  const AppShortcut({
    required this.label,
    required this.keysLabel,
    required this.activators,
    this.path,
  });

  /// Human-readable action, e.g. "Home".
  final String label;

  /// Human-readable key combination, e.g. "Alt + H".
  ///
  /// Multiple combinations are separated by "·", e.g. "F1 · Ctrl + /".
  final String keysLabel;

  /// The key combinations that trigger this shortcut.
  final List<ShortcutActivator> activators;

  /// Route to navigate to when the shortcut fires (navigation shortcuts).
  final String? path;

  /// [keysLabel] split into combinations, then into individual key caps.
  List<List<String>> get keyCombos => keysLabel
      .split('·')
      .map((combo) => combo.split('+').map((key) => key.trim()).toList())
      .toList();
}

/// Shows the keyboard shortcuts help dialog (F1, Ctrl+/, or ?).
final helpShortcut = AppShortcut(
  label: 'Show keyboard shortcuts',
  keysLabel: 'F1 · Ctrl + / · ?',
  activators: const [
    SingleActivator(LogicalKeyboardKey.f1),
    SingleActivator(LogicalKeyboardKey.slash, control: true),
    SingleActivator(LogicalKeyboardKey.slash, shift: true),
  ],
);

/// Navigation shortcuts available for [role], matching the bottom tabs and
/// the "More" screen.
List<AppShortcut> navigationShortcuts(UserRole role) {
  const all = <AppShortcut>[
    AppShortcut(
      label: 'Home',
      path: '/',
      keysLabel: 'Alt + H',
      activators: [SingleActivator(LogicalKeyboardKey.keyH, alt: true)],
    ),
    AppShortcut(
      label: 'Roster',
      path: '/roster',
      keysLabel: 'Alt + R',
      activators: [SingleActivator(LogicalKeyboardKey.keyR, alt: true)],
    ),
    AppShortcut(
      label: 'Users',
      path: '/users',
      keysLabel: 'Alt + U',
      activators: [SingleActivator(LogicalKeyboardKey.keyU, alt: true)],
    ),
    AppShortcut(
      label: 'Attendance',
      path: '/attendance',
      keysLabel: 'Alt + A',
      activators: [SingleActivator(LogicalKeyboardKey.keyA, alt: true)],
    ),
    AppShortcut(
      label: 'Homework',
      path: '/homework',
      keysLabel: 'Alt + W',
      activators: [SingleActivator(LogicalKeyboardKey.keyW, alt: true)],
    ),
    AppShortcut(
      label: 'Timetable',
      path: '/timetable',
      keysLabel: 'Alt + T',
      activators: [SingleActivator(LogicalKeyboardKey.keyT, alt: true)],
    ),
    AppShortcut(
      label: 'Marks & reports',
      path: '/marks',
      keysLabel: 'Alt + G',
      activators: [SingleActivator(LogicalKeyboardKey.keyG, alt: true)],
    ),
    AppShortcut(
      label: 'Announcements',
      path: '/announcements',
      keysLabel: 'Alt + N',
      activators: [SingleActivator(LogicalKeyboardKey.keyN, alt: true)],
    ),
    AppShortcut(
      label: 'PTM',
      path: '/ptm',
      keysLabel: 'Alt + P',
      activators: [SingleActivator(LogicalKeyboardKey.keyP, alt: true)],
    ),
    AppShortcut(
      label: 'Account details',
      path: '/account',
      keysLabel: 'Alt + C',
      activators: [SingleActivator(LogicalKeyboardKey.keyC, alt: true)],
    ),
    AppShortcut(
      label: 'More',
      path: '/more',
      keysLabel: 'Alt + M',
      activators: [SingleActivator(LogicalKeyboardKey.keyM, alt: true)],
    ),
  ];

  final allowed = _allowedPaths(role);
  return all.where((shortcut) => allowed.contains(shortcut.path)).toList();
}

Set<String> _allowedPaths(UserRole role) => switch (role) {
  UserRole.admin => const {
    '/',
    '/roster',
    '/users',
    '/attendance',
    '/homework',
    '/timetable',
    '/marks',
    '/announcements',
    '/ptm',
    '/more',
  },
  UserRole.teacher || UserRole.floorIncharge => const {
    '/',
    '/attendance',
    '/homework',
    '/timetable',
    '/marks',
    '/announcements',
    '/ptm',
    '/more',
  },
  UserRole.viewer => const {
    '/',
    '/attendance',
    '/homework',
    '/account',
    '/timetable',
    '/marks',
    '/announcements',
    '/ptm',
    '/more',
  },
};

/// Shows the keyboard shortcuts help dialog for [role].
Future<void> showKeyboardShortcutsDialog(BuildContext context, UserRole role) {
  return showDialog<void>(
    context: context,
    builder: (context) => KeyboardShortcutsDialog(role: role),
  );
}

/// Wraps the app so the keyboard shortcuts work everywhere.
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).valueOrNull?.role ?? UserRole.viewer;
    final router = ref.read(routerProvider);

    void showHelp() {
      final state = rootNavigatorKey.currentState;
      if (state == null) return;
      showKeyboardShortcutsDialog(state.context, role);
    }

    final bindings = <ShortcutActivator, VoidCallback>{
      for (final shortcut in navigationShortcuts(role))
        for (final activator in shortcut.activators)
          activator: () => router.go(shortcut.path!),
      for (final activator in helpShortcut.activators) activator: showHelp,
    };

    return CallbackShortcuts(bindings: bindings, child: child);
  }
}

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final navigation = navigationShortcuts(role);
    return AlertDialog(
      icon: const Icon(Icons.keyboard_outlined),
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Navigation'),
              for (final shortcut in navigation)
                _ShortcutRow(shortcut: shortcut),
              const SizedBox(height: 16),
              const _SectionTitle('General'),
              _ShortcutRow(shortcut: helpShortcut),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.shortcut});

  final AppShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(shortcut.label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          for (var i = 0; i < shortcut.keyCombos.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('or', style: theme.textTheme.bodySmall),
              ),
            for (final key in shortcut.keyCombos[i]) ...[
              _KeyCap(key),
              const SizedBox(width: 4),
            ],
          ],
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
