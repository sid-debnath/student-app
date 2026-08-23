import 'package:flutter/material.dart';

import '../core/branding.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 72, this.brand});

  final double height;
  final BrandConfig? brand;

  @override
  Widget build(BuildContext context) {
    final config = brand ?? BrandConfig.current;
    return Image(
      image: config.logoProvider,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.account_balance_outlined,
        size: height,
        color: config.primaryColor,
      ),
    );
  }
}
