import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

class AppTheme {
  static OutlineInputBorder _b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: Rad.md,
    borderSide: BorderSide(color: c, width: w),
  );
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: NimzoColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NimzoColors.primary,
      primary: NimzoColors.primary,
      error: NimzoColors.error,
      surface: NimzoColors.surface,
      onSurface: NimzoColors.text,
    ),
    textTheme: NimzoType.textTheme(),
    dividerColor: NimzoColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: NimzoColors.background,
      foregroundColor: NimzoColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: NimzoColors.primaryDark,
      unselectedLabelColor: NimzoColors.textSecondary,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      indicatorColor: NimzoColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: NimzoColors.border,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NimzoColors.surface,
      selectedColor: NimzoColors.primaryLight,
      showCheckmark: false,
      side: const BorderSide(color: NimzoColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: const TextStyle(fontSize: 12, color: NimzoColors.text),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: Rad.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      fillColor: NimzoColors.surface,
      border: _b(NimzoColors.border),
      enabledBorder: _b(NimzoColors.border),
      focusedBorder: _b(NimzoColors.primary, 1.5),
    ),
  );
}
