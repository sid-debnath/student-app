import 'package:flutter/material.dart';

import 'branding.dart';
import 'constants.dart';
import 'theme.dart';

/// A user-selectable theme.
///
/// Themes are plain data (`id` + `label` + a builder) rather than a fixed enum,
/// so adding a theme is a single entry in [appThemes] with no changes to
/// storage, providers, or the picker UI. Each builder receives the active
/// [BrandConfig], so every theme automatically follows the current brand's
/// seed color.
class AppTheme {
  const AppTheme({
    required this.id,
    required this.label,
    required this.build,
  });

  final String id;
  final String label;

  /// Builds this theme's [ThemeData] from the active brand seed.
  final ThemeData Function(BrandConfig brand) build;
}

/// All themes users can select, in display order.
const appThemes = <AppTheme>[
  AppTheme(id: kLightThemeId, label: 'Light', build: _buildLightTheme),
  AppTheme(id: kDarkThemeId, label: 'Dark', build: _buildDarkTheme),
];

ThemeData _buildLightTheme(BrandConfig brand) =>
    buildAppTheme(brand, Brightness.light);

ThemeData _buildDarkTheme(BrandConfig brand) =>
    buildAppTheme(brand, Brightness.dark);

/// Resolves a stored theme id to an [AppTheme]; unknown ids fall back to the
/// default theme.
AppTheme appThemeFromId(String? id) => appThemes.firstWhere(
  (theme) => theme.id == id,
  orElse: () => appThemes.firstWhere((theme) => theme.id == kDefaultThemeId),
);

/// Builds the [ThemeData] for a stored theme id (defaults to the default theme).
ThemeData buildTheme(BrandConfig brand, String? id) =>
    appThemeFromId(id).build(brand);