import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/institution.dart';

/// White-label look for one customer binary.
///
/// Active files live in `assets/branding/`. Swap a customer by copying
/// `brands/<id>/` there (`dart run tool/apply_brand.dart <id>`).
class BrandConfig {
  const BrandConfig({
    required this.id,
    required this.displayName,
    required this.tagline,
    required this.primaryColor,
    required this.logoAsset,
    required this.backgroundAsset,
    required this.splashAsset,
    this.logoUrl,
    this.backgroundUrl,
  });

  static const assetFolder = 'assets/branding';
  static const jsonAsset = 'assets/branding/brand.json';

  static const fallback = BrandConfig(
    id: 'default',
    displayName: 'Student App',
    tagline: 'Attendance, homework, timetable, marks, announcements, and PTM.',
    primaryColor: Color(0xFF0F6A8A),
    logoAsset: 'assets/branding/logo.png',
    backgroundAsset: 'assets/branding/background.png',
    splashAsset: 'assets/branding/splash.png',
  );

  static BrandConfig current = fallback;

  final String id;
  final String displayName;
  final String tagline;
  final Color primaryColor;
  final String logoAsset;
  final String backgroundAsset;
  final String splashAsset;
  final String? logoUrl;
  final String? backgroundUrl;

  ImageProvider get logoProvider {
    final url = logoUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return AssetImage(logoAsset);
  }

  ImageProvider get backgroundProvider {
    final url = backgroundUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return AssetImage(backgroundAsset);
  }

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(jsonAsset);
      current = fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      current = fallback;
    }
  }

  static BrandConfig fromJson(Map<String, dynamic> json) {
    return BrandConfig(
      id: json['id'] as String? ?? 'default',
      displayName: json['displayName'] as String? ?? fallback.displayName,
      tagline: json['tagline'] as String? ?? fallback.tagline,
      primaryColor: parseColor(json['primaryColor'] as String?) ?? fallback.primaryColor,
      logoAsset: _asset(json['logo'] as String? ?? 'logo.png'),
      backgroundAsset: _asset(json['background'] as String? ?? 'background.png'),
      splashAsset: _asset(json['splash'] as String? ?? 'splash.png'),
      logoUrl: _nonEmpty(json['logoUrl'] as String?),
      backgroundUrl: _nonEmpty(json['backgroundUrl'] as String?),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'displayName': displayName,
    'tagline': tagline,
    'primaryColor': colorToHex(primaryColor),
    'logoUrl': logoUrl ?? '',
    'backgroundUrl': backgroundUrl ?? '',
  };

  BrandConfig mergeInstitution(Institution? institution) {
    if (institution == null) return this;
    final remote = institution.branding;
    return BrandConfig(
      id: id,
      displayName: _nonEmpty(remote.displayName) ??
          (institution.name.isEmpty ? displayName : institution.name),
      tagline: _nonEmpty(remote.tagline) ?? tagline,
      primaryColor: parseColor(remote.primaryColor) ?? primaryColor,
      logoAsset: logoAsset,
      backgroundAsset: backgroundAsset,
      splashAsset: splashAsset,
      logoUrl: _nonEmpty(remote.logoUrl) ?? logoUrl,
      backgroundUrl: _nonEmpty(remote.backgroundUrl) ?? backgroundUrl,
    );
  }

  static String _asset(String fileName) {
    if (fileName.startsWith('assets/')) return fileName;
    return '$assetFolder/$fileName';
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static String colorToHex(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }
}
