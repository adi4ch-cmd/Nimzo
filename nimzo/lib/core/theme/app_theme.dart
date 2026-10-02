import 'package:flutter/material.dart';
import 'colors.dart';
import 'radius.dart';
import 'typography.dart';

class AppTheme {
  static OutlineInputBorder _b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: Rad.md, borderSide: BorderSide(color: c, width: w));

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: NimzoColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NimzoColors.primary,
          primary: NimzoColors.primary,
          error: NimzoColors.error,
          surface: NimzoColors.surface,
        ),
        textTheme: NimzoType.textTheme(),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NimzoColors.surface,
          border: _b(NimzoColors.border),
          enabledBorder: _b(NimzoColors.border),
          focusedBorder: _b(NimzoColors.primary, 1.5),
        ),
      );
}
