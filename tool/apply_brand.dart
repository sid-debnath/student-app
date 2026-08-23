import 'dart:io';

/// Copies `brands/<id>/` into `assets/branding/` (the pack the app ships).
///
/// ```sh
/// dart run tool/apply_brand.dart default
/// dart run flutter_launcher_icons
/// ```
void main(List<String> args) {
  final id = args.isEmpty ? 'default' : args.first;
  final root = Directory.current;
  final source = Directory('${root.path}/brands/$id');
  final dest = Directory('${root.path}/assets/branding');
  if (!source.existsSync()) {
    stderr.writeln('No brand pack at brands/$id');
    stderr.writeln('Copy brands/_template to brands/$id and add logo.png, background.png, app_icon.png.');
    exitCode = 1;
    return;
  }

  dest.createSync(recursive: true);
  for (final entity in dest.listSync()) {
    if (entity is File) entity.deleteSync();
  }
  for (final entity in source.listSync()) {
    if (entity is File) {
      entity.copySync('${dest.path}/${entity.uri.pathSegments.last}');
    }
  }
  stdout.writeln('Active brand is now "$id" (assets/branding).');
  stdout.writeln('Regenerate launcher icons:');
  stdout.writeln('  dart run flutter_launcher_icons');
}
