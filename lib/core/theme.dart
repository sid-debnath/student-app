import 'package:flutter/material.dart';

import 'branding.dart';

ThemeData buildAppTheme([
  BrandConfig? brand,
  Brightness brightness = Brightness.light,
]) {
  final seed = (brand ?? BrandConfig.current).primaryColor;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final dark = brightness == Brightness.dark;
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
    extensions: [
      StatusPalette(
        success: dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
        warning: dark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00),
        danger: dark ? const Color(0xFFE57373) : const Color(0xFFC62828),
        muted: dark ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
      ),
    ],
  );
}

/// Semantic status colors that adapt to light/dark, exposed as a theme
/// extension so screens (e.g. attendance) stay brand/theme agnostic.
@immutable
class StatusPalette extends ThemeExtension<StatusPalette> {
  const StatusPalette({
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;

  @override
  StatusPalette copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? muted,
  }) {
    return StatusPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      muted: muted ?? this.muted,
    );
  }

  @override
  StatusPalette lerp(ThemeExtension<StatusPalette>? other, double t) {
    if (other is! StatusPalette) return this;
    return StatusPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}
