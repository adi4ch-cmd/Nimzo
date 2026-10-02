import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class NimzoType {
  static TextTheme textTheme() => GoogleFonts.interTextTheme().copyWith(
        headlineMedium: GoogleFonts.inter(
            fontSize: 26, fontWeight: FontWeight.w700, color: NimzoColors.text),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, color: NimzoColors.text),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, color: NimzoColors.text, height: 1.4),
        bodySmall:
            GoogleFonts.inter(fontSize: 12, color: NimzoColors.textSecondary),
      );
}
