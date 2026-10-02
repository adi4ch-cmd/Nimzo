import 'package:flutter/material.dart';

/// Themes change colours/background/effects ONLY. Never coins, gifts, voice, permissions or wallet.
class RoomTheme {
  final String key, label;
  final Color background, accent, text;
  const RoomTheme(this.key, this.label, this.background, this.accent, this.text);
}

const roomThemes = <RoomTheme>[
  RoomTheme('nimzo_white', 'Nimzo White', Color(0xFFFFFFFF), Color(0xFF22C55E), Color(0xFF111827)),
  RoomTheme('sage', 'Sage', Color(0xFFEFF5EF), Color(0xFF6B8F71), Color(0xFF1F2A22)),
  RoomTheme('ocean', 'Ocean', Color(0xFFE8F3FA), Color(0xFF2E86AB), Color(0xFF10232E)),
  RoomTheme('lavender', 'Lavender', Color(0xFFF3EFFA), Color(0xFF8B7BC8), Color(0xFF241F33)),
  RoomTheme('rose', 'Rose', Color(0xFFFCEFF1), Color(0xFFD16B7C), Color(0xFF33191E)),
  RoomTheme('midnight', 'Midnight', Color(0xFF0F172A), Color(0xFF38BDF8), Color(0xFFF1F5F9)),
  RoomTheme('premium_black', 'Premium Black', Color(0xFF0A0A0A), Color(0xFFF5C451), Color(0xFFF5F5F5)),
  RoomTheme('luxury', 'Luxury', Color(0xFF1C1408), Color(0xFFF5C451), Color(0xFFFFF4D6)),
];

RoomTheme themeFor(String key) => roomThemes.firstWhere((t) => t.key == key, orElse: () => roomThemes.first);
