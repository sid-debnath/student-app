import 'package:flutter/material.dart';

import 'branding.dart';

ThemeData buildAppTheme([BrandConfig? brand]) {
  final seed = (brand ?? BrandConfig.current).primaryColor;
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
