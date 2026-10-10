import 'package:flutter/material.dart';

/// Verified, logo-free original gift-tray artwork licensed for NIMZO.
/// Backend-controlled gift IDs, values and entitlements remain unchanged.
class NimzoGiftControlArt extends StatelessWidget {
  const NimzoGiftControlArt(
    this.filename, {
    super.key,
    this.width = 24,
    this.height = 24,
    this.fallback,
  });

  final String filename;
  final double width;
  final double height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/nimzo/gift_controls/$filename',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
      );
}
