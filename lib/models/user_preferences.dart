import '../core/constants.dart';

/// User-controlled preferences, persisted on the user profile under the
/// `preferences` map.
///
/// Design: each preference is a single key inside `preferences`, so future
/// preferences (notifications, locale, etc.) can be added without a schema
/// migration. The theme preference stores the **id** of the selected
/// [AppTheme] (see `lib/core/app_theme.dart`), so adding themes later never
/// requires a storage migration — unknown ids simply fall back to the default.
class UserPreferences {
  const UserPreferences({
    this.themeId = kDefaultThemeId,
    this.values = const {},
  });

  /// The key used for the theme preference inside the `preferences` map.
  static const themeIdKey = 'themeId';

  /// Id of the selected theme (e.g. `light`, `dark`).
  final String themeId;

  /// All raw preference key/value pairs, including keys not yet modelled as
  /// typed fields. Written back verbatim so future preferences are preserved.
  final Map<String, dynamic> values;

  factory UserPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return const UserPreferences();
    final values = Map<String, dynamic>.from(data);
    return UserPreferences(
      themeId: (values[themeIdKey] as String?) ?? kDefaultThemeId,
      values: values,
    );
  }

  UserPreferences copyWith({String? themeId}) {
    return UserPreferences(
      themeId: themeId ?? this.themeId,
      values: {
        ...values,
        themeIdKey: ?themeId,
      },
    );
  }

  Map<String, dynamic> toMap() => {
    ...values,
    themeIdKey: themeId,
  };
}
