import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/app_theme.dart';
import 'package:student_app/core/branding.dart';
import 'package:student_app/core/constants.dart';
import 'package:student_app/core/theme.dart';
import 'package:student_app/models/app_user.dart';
import 'package:student_app/models/user_preferences.dart';

void main() {
  test('theme catalog exposes light and dark with stable ids', () {
    expect(
      appThemes.map((theme) => theme.id),
      containsAll([kLightThemeId, kDarkThemeId]),
    );
    expect(appThemeFromId(null).id, kDefaultThemeId);
    expect(appThemeFromId('unknown').id, kDefaultThemeId);
    expect(appThemeFromId(kDarkThemeId).id, kDarkThemeId);
  });

  test('theme builders produce the expected brightness', () {
    expect(buildAppTheme(null, Brightness.light).brightness, Brightness.light);
    expect(buildAppTheme(null, Brightness.dark).brightness, Brightness.dark);
    expect(buildTheme(BrandConfig.current, null).brightness, Brightness.light);
  });

  test('status palette adapts to light and dark', () {
    final light =
        buildAppTheme(null, Brightness.light).extension<StatusPalette>()!;
    final dark =
        buildAppTheme(null, Brightness.dark).extension<StatusPalette>()!;
    expect(light.success, isNot(dark.success));
    expect(light.warning, isNot(dark.warning));
    expect(light.danger, isNot(dark.danger));
  });

  test('preferences default to the default theme id', () {
    const prefs = UserPreferences();
    expect(prefs.themeId, kDefaultThemeId);
    expect(prefs.values, isEmpty);
  });

  test('preferences round-trip preserves unknown future keys', () {
    final prefs = UserPreferences.fromMap({
      'themeId': 'dark',
      'locale': 'en-IN',
    });
    expect(prefs.themeId, 'dark');
    expect(prefs.values['locale'], 'en-IN');

    final map = prefs.toMap();
    expect(map['themeId'], 'dark');
    expect(map['locale'], 'en-IN');
  });

  test('copyWith updates themeId while keeping other keys', () {
    final prefs = UserPreferences.fromMap({
      'themeId': 'light',
      'locale': 'hi',
    });
    final updated = prefs.copyWith(themeId: 'dark');
    expect(updated.themeId, 'dark');
    expect(updated.values['locale'], 'hi');
    expect(updated.toMap()['themeId'], 'dark');
  });

  test('AppUser reads preferences from the profile map', () {
    final dark = AppUser.fromMap('u1', {
      'preferences': {'themeId': 'dark'},
    });
    expect(dark.preferences.themeId, 'dark');

    final legacy = AppUser.fromMap('u2', {});
    expect(legacy.preferences.themeId, kDefaultThemeId);
  });
}
