import 'package:flutter/material.dart';
import '../widgets/master_ui.dart';

/// Tokens read from nimzo-ui-2.html. Prototype balances are never design tokens.
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
        actionIconTheme: ActionIconThemeData(
            backButtonIconBuilder: (_) => const Padding(
                padding: EdgeInsets.only(left: 12),
                child: ReferenceIcon('back'))),
        textTheme: const TextTheme(
          bodyMedium:
              TextStyle(fontSize: 14, height: 1.4, color: NimzoStyle.ink),
          bodySmall: TextStyle(fontSize: 12, color: NimzoStyle.muted),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
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
              color: NimzoStyle.ink),
          subtitleTextStyle: TextStyle(
              fontFamily: 'Roboto', fontSize: 12, color: NimzoStyle.muted),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)))),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? NimzoStyle.primary
                  : const Color(0xffd6cce6)),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
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
