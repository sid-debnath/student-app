/// Build-time edition. Default is Spark (no-cost).
///
/// ```sh
/// flutter run -d chrome
/// flutter run -d chrome --dart-define=APP_EDITION=production
/// flutter build web --dart-define=APP_EDITION=production
/// ```
class AppConfig {
  static const editionName = String.fromEnvironment(
    'APP_EDITION',
    defaultValue: 'spark',
  );

  static bool get isProduction => editionName == 'production';
  static bool get isSpark => !isProduction;

  /// Callables in `functions/` (user create, FCM send). Off on Spark.
  static bool get useCloudFunctions => isProduction;

  /// Firebase Storage uploads. Off on Spark until a bucket exists and Blaze is on.
  static bool get useStorage => isProduction;

  /// Server-side FCM via Functions. Client topic subscribe stays on in both editions.
  static bool get useServerFcm => isProduction;
}
