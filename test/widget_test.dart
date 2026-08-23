import 'package:flutter_test/flutter_test.dart';

import 'package:student_app/core/theme.dart';

void main() {
  test('app theme uses Material 3', () {
    expect(buildAppTheme().useMaterial3, isTrue);
  });
}
