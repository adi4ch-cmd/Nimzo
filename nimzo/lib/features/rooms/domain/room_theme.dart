import 'package:flutter/material.dart';

/// Themes change colors, background and effects ONLY. They never touch
/// coins, gifts, voice, permissions or wallet.
class RoomTheme {
  final String id, label;
  final List<Color> gradient;
  final Color text;
  const RoomTheme(this.id, this.label, this.gradient, this.text);

  static const all = [
    RoomTheme('nimzo_white', 'Nimzo White', [
      Color(0xFFFFFFFF),
      Color(0xFFF0FDF4),
    ], Color(0xFF111827)),
    RoomTheme('sage', 'Sage', [
      Color(0xFFECF3EC),
      Color(0xFFCFE0CF),
    ], Color(0xFF1F2D1F)),
    RoomTheme('ocean', 'Ocean', [
      Color(0xFFE0F2FE),
      Color(0xFF93C5FD),
    ], Color(0xFF0C2340)),
    RoomTheme('lavender', 'Lavender', [
      Color(0xFFF3E8FF),
      Color(0xFFD8B4FE),
    ], Color(0xFF2E1065)),
    RoomTheme('rose', 'Rose', [
      Color(0xFFFFE4E6),
      Color(0xFFFDA4AF),
    ], Color(0xFF4C0519)),
    RoomTheme('midnight', 'Midnight', [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
    ], Color(0xFFF1F5F9)),
    RoomTheme('premium_black', 'Premium Black', [
      Color(0xFF000000),
      Color(0xFF18181B),
    ], Color(0xFFF5C451)),
    RoomTheme('luxury', 'Luxury', [
      Color(0xFF1C1917),
      Color(0xFF44403C),
    ], Color(0xFFF5C451)),
  ];
  static RoomTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
