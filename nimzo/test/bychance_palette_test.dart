import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';

void main() {
  test('ByChance-inspired palette keeps NIMZO identity consistent', () {
    expect(NimzoStyle.primary, const Color(0xff8b3dff));
    expect(NimzoStyle.pink, const Color(0xfff45191));
    expect(NimzoStyle.blue, const Color(0xff298df5));
    expect(NimzoStyle.orange, const Color(0xffff941f));
    expect(NimzoStyle.royal, const Color(0xff6628cf));
    expect(NimzoStyle.heroGradient.colors, <Color>[
      NimzoStyle.royal,
      NimzoStyle.primary,
      NimzoStyle.pink,
    ]);
  });

  test('Material theme uses readable surfaces and unified accents', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, NimzoStyle.primary);
    expect(theme.colorScheme.secondary, NimzoStyle.pink);
    expect(theme.colorScheme.tertiary, NimzoStyle.orange);
    expect(theme.scaffoldBackgroundColor, NimzoStyle.surface);
    expect(theme.colorScheme.onSurface, NimzoStyle.ink);
  });
}
