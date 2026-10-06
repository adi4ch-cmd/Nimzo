import 'package:flutter/material.dart';

import 'colors.dart';

class NimzoType {
  /// Uses the device's local typeface, including its Arabic fallback. Rendering
  /// never waits for a font download on the first launch.
  static TextTheme textTheme() => const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
      color: NimzoColors.text,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: -.3,
      color: NimzoColors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: NimzoColors.text,
      height: 1.35,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: NimzoColors.text,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: NimzoColors.text, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, color: NimzoColors.text, height: 1.45),
    bodySmall: TextStyle(
      fontSize: 12,
      color: NimzoColors.textSecondary,
      height: 1.4,
    ),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: NimzoColors.textSecondary,
    ),
  );
}
