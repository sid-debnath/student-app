import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/keyboard_shortcuts.dart';
import 'package:student_app/models/app_user.dart';

void main() {
  test('navigation shortcuts are scoped to each role', () {
    final admin = navigationShortcuts(UserRole.admin);
    final teacher = navigationShortcuts(UserRole.teacher);
    final viewer = navigationShortcuts(UserRole.viewer);

    expect(admin.map((s) => s.path), containsAll(['/roster', '/users']));
    expect(admin.any((s) => s.path == '/account'), isFalse);

    expect(teacher.any((s) => s.path == '/roster'), isFalse);
    expect(teacher.any((s) => s.path == '/users'), isFalse);

    expect(viewer.any((s) => s.path == '/account'), isTrue);
    expect(viewer.any((s) => s.path == '/roster'), isFalse);
    expect(viewer.any((s) => s.path == '/users'), isFalse);
  });

  test('every navigation shortcut has a single unique key combination', () {
    final all = navigationShortcuts(UserRole.admin);
    final activators = all.expand((s) => s.activators).toList();
    expect(activators.toSet().length, activators.length);
  });

  test('help shortcut is always available', () {
    expect(helpShortcut.activators, isNotEmpty);
    expect(helpShortcut.path, isNull);
  });
}
