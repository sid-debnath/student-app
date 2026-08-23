import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/core/branding.dart';

void main() {
  test('parses brand.json and hex colors', () {
    final brand = BrandConfig.fromJson({
      'id': 'northgate',
      'displayName': 'Northgate College',
      'tagline': 'Learn well.',
      'primaryColor': '#0F6A8A',
      'logo': 'logo.png',
      'background': 'background.png',
      'splash': 'splash.png',
    });
    expect(brand.displayName, 'Northgate College');
    expect(brand.primaryColor, const Color(0xFF0F6A8A));
    expect(brand.logoAsset, 'assets/branding/logo.png');
  });
}
