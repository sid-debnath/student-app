import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/app_config.dart';
import 'package:student_app/core/theme.dart';

void main() {
  test('app theme uses Material 3', () {
    expect(buildAppTheme().useMaterial3, isTrue);
  });

  test('default edition is Spark (no-cost)', () {
    expect(AppConfig.isSpark, isTrue);
    expect(AppConfig.isProduction, isFalse);
    expect(AppConfig.useCloudFunctions, isFalse);
    expect(AppConfig.useStorage, isFalse);
    expect(AppConfig.useServerFcm, isFalse);
  });
}
