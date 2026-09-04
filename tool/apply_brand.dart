import 'dart:convert';
import 'dart:io';

/// Applies a brand pack for one customer build.
///
/// 1. Copies `brands/<id>/` assets into `assets/branding/` (what the app ships).
/// 2. Writes the `displayName` and `primaryColor` from `brand.json` into the
///    platform metadata so the launcher name and web title match the brand:
///    - android/app/src/main/AndroidManifest.xml  (android:label)
///    - ios/Runner/Info.plist                      (CFBundleDisplayName, CFBundleName)
///    - web/index.html                             (<title>, apple-mobile-web-app-title, description)
///    - web/manifest.json                          (name, short_name, theme_color, background_color, description)
///    - pubspec.yaml                               (flutter_native_splash color)
///
/// Launcher icons and the native splash are regenerated separately:
///
/// ```sh
/// dart run tool/apply_brand.dart <id>
/// dart run flutter_native_splash:create
/// dart run flutter_launcher_icons
/// ```
void main(List<String> args) {
  final id = args.isEmpty ? 'default' : args.first;
  final root = Directory.current;
  final source = Directory('${root.path}/brands/$id');
  if (!source.existsSync()) {
    stderr.writeln('No brand pack at brands/$id');
    stderr.writeln(
      'Copy brands/_template to brands/$id and add logo.png, background.png, '
      'app_icon.png, splash.png.',
    );
    exitCode = 1;
    return;
  }

  final jsonFile = File('${source.path}/brand.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('Missing brands/$id/brand.json');
    exitCode = 1;
    return;
  }

  final Map<String, dynamic> brand;
  try {
    brand = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (error) {
    stderr.writeln('Could not parse brands/$id/brand.json: ${error.message}');
    exitCode = 1;
    return;
  }

  final displayName = (brand['displayName'] as String? ?? '').trim();
  if (displayName.isEmpty) {
    stderr.writeln('brand.json must set a non-empty "displayName".');
    exitCode = 1;
    return;
  }
  final tagline = (brand['tagline'] as String? ?? '').trim();
  final primaryColor = _normalizeHex(brand['primaryColor'] as String?);

  // 1. Copy assets into the active folder the app ships.
  final dest = Directory('${root.path}/assets/branding');
  dest.createSync(recursive: true);
  for (final entity in dest.listSync()) {
    if (entity is File) entity.deleteSync();
  }
  for (final entity in source.listSync()) {
    if (entity is File) {
      entity.copySync('${dest.path}/${entity.uri.pathSegments.last}');
    }
  }

  // 2. Write platform metadata.
  _applyAndroidLabel(root, displayName);
  _applyIosNames(root, displayName);
  _applyWebIndex(root, displayName, tagline);
  _applyWebManifest(root, displayName, tagline, primaryColor);
  _applySplashColor(root, primaryColor);

  stdout.writeln('Active brand is now "$id" (assets/branding).');
  stdout.writeln('Platform display name set to "$displayName".');
  stdout.writeln('Regenerate launcher icons and native splash:');
  stdout.writeln('  dart run flutter_native_splash:create');
  stdout.writeln('  dart run flutter_launcher_icons');
}

void _applyAndroidLabel(Directory root, String displayName) {
  final file = File('${root.path}/android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) return;
  _replaceInFile(
    file,
    RegExp('android:label="[^"]*"'),
    'android:label="${_xmlEscape(displayName)}"',
  );
}

void _applyIosNames(Directory root, String displayName) {
  final file = File('${root.path}/ios/Runner/Info.plist');
  if (!file.existsSync()) return;
  final escaped = _xmlEscape(displayName);
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    RegExp('<key>CFBundleDisplayName</key>\\s*<string>.*?</string>'),
    '<key>CFBundleDisplayName</key>\n\t<string>$escaped</string>',
  );
  content = content.replaceFirst(
    RegExp('<key>CFBundleName</key>\\s*<string>.*?</string>'),
    '<key>CFBundleName</key>\n\t<string>$escaped</string>',
  );
  file.writeAsStringSync(content);
}

void _applyWebIndex(Directory root, String displayName, String tagline) {
  final file = File('${root.path}/web/index.html');
  if (!file.existsSync()) return;
  final name = _htmlEscape(displayName);
  final description = _htmlEscape(tagline.isEmpty ? displayName : tagline);
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    RegExp('<title>.*?</title>'),
    '<title>$name</title>',
  );
  content = content.replaceFirst(
    RegExp('<meta name="apple-mobile-web-app-title" content=".*?">'),
    '<meta name="apple-mobile-web-app-title" content="$name">',
  );
  content = content.replaceFirst(
    RegExp('<meta name="description" content=".*?">'),
    '<meta name="description" content="$description">',
  );
  file.writeAsStringSync(content);
}

void _applyWebManifest(
  Directory root,
  String displayName,
  String tagline,
  String? primaryColor,
) {
  final file = File('${root.path}/web/manifest.json');
  if (!file.existsSync()) return;
  final Map<String, dynamic> manifest;
  try {
    manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException {
    return; // Leave untouched if the manifest is not parseable.
  }
  manifest['name'] = displayName;
  manifest['short_name'] = displayName;
  manifest['description'] = tagline.isEmpty ? displayName : tagline;
  if (primaryColor != null && primaryColor.isNotEmpty) {
    manifest['background_color'] = primaryColor;
    manifest['theme_color'] = primaryColor;
  }
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('    ').convert(manifest)}\n',
  );
}

/// Writes the brand color into the `flutter_native_splash` config in
/// `pubspec.yaml` so `dart run flutter_native_splash:create` regenerates the
/// native/web splash with the matching background color.
void _applySplashColor(Directory root, String? primaryColor) {
  if (primaryColor == null || primaryColor.isEmpty) return;
  final file = File('${root.path}/pubspec.yaml');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  content = content.replaceFirstMapped(
    RegExp(r'(flutter_native_splash:\s*\n\s*color:\s*")[^"]*(")'),
    (m) => '${m[1]}$primaryColor${m[2]}',
  );
  content = content.replaceFirstMapped(
    RegExp(r'(android_12:\s*\n\s*color:\s*")[^"]*(")'),
    (m) => '${m[1]}$primaryColor${m[2]}',
  );
  file.writeAsStringSync(content);
}

void _replaceInFile(File file, RegExp pattern, String replacement) {
  final content = file.readAsStringSync();
  if (pattern.hasMatch(content)) {
    file.writeAsStringSync(content.replaceFirst(pattern, replacement));
  }
}

String? _normalizeHex(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (!hex.startsWith('#')) hex = '#$hex';
  return hex.toUpperCase();
}

String _xmlEscape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _htmlEscape(String input) => _xmlEscape(input);
