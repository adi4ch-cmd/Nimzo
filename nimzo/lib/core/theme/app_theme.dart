import 'package:flutter/material.dart';

/// Tokens read from nimzo-ui-1.html. Prototype balances are never design tokens.
abstract final class NimzoStyle {
  static const primary = Color(0xff9333ea);
  static const pink = Color(0xffec4899);
  static const surface = Color(0xfffaf5ff);
  static const ink = Color(0xff14201a);
  static const muted = Color(0xff6b7a72);
  static const line = Color(0xffe9def8);
  static const gradient = LinearGradient(
    colors: [Color(0xff8b2cf5), pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const pagePadding = EdgeInsets.all(16);
}

abstract final class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme:
            ColorScheme.fromSeed(seedColor: NimzoStyle.primary).copyWith(
          primary: NimzoStyle.primary,
          secondary: NimzoStyle.pink,
          surface: Colors.white,
          onSurface: NimzoStyle.ink,
        ),
        dividerColor: NimzoStyle.line,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: NimzoStyle.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: NimzoStyle.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NimzoStyle.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: NimzoStyle.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: NimzoStyle.line),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
