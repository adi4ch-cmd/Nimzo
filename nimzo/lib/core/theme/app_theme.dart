import 'package:flutter/material.dart';

import '../widgets/master_ui.dart';

/// NIMZO green and white foundation shared by original app components.
/// These are independently authored colors; no third-party artwork is bundled.
abstract final class NimzoStyle {
  static const primary = Color(0xff087f5b);
  static const pink = Color(0xffed428c);
  static const blue = Color(0xff3a85ff);
  static const orange = Color(0xffffab21);
  static const royal = Color(0xff056647);
  static const surface = Color(0xfff5faf7);
  static const ink = Color(0xff142b23);
  static const muted = Color(0xff60756b);
  static const line = Color(0xffe1eee7);
  static const gradient = LinearGradient(
    colors: [primary, royal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [primary, royal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const softGradient = LinearGradient(
    colors: [Color(0xffd8f3e6), Color(0xffedf9f1), Color(0xfffbfefc)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const goldGradient = LinearGradient(
    colors: [Color(0xffffb14b), orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const pagePadding = EdgeInsets.all(16);
}

abstract final class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: NimzoStyle.surface,
        colorScheme:
            ColorScheme.fromSeed(seedColor: NimzoStyle.primary).copyWith(
          primary: NimzoStyle.primary,
          secondary: NimzoStyle.pink,
          tertiary: NimzoStyle.orange,
          surface: Colors.white,
          onSurface: NimzoStyle.ink,
        ),
        dividerColor: NimzoStyle.line,
        splashColor: NimzoStyle.primary.withValues(alpha: .07),
        highlightColor: NimzoStyle.primary.withValues(alpha: .04),
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (_) => const Padding(
            padding: EdgeInsets.only(left: 12),
            child: ReferenceIcon('back'),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium:
              TextStyle(fontSize: 14, height: 1.4, color: NimzoStyle.ink),
          bodySmall: TextStyle(fontSize: 12, color: NimzoStyle.muted),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: NimzoStyle.ink,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: NimzoStyle.ink,
          ),
          subtitleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: NimzoStyle.muted,
          ),
        ),
        appBarTheme: const AppBarTheme(
          titleSpacing: 8,
          leadingWidth: 46,
          backgroundColor: Colors.white,
          foregroundColor: NimzoStyle.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: NimzoStyle.line)),
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: NimzoStyle.primary,
            side: const BorderSide(color: NimzoStyle.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? NimzoStyle.primary
                : const Color(0xffd6cce6),
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: NimzoStyle.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
