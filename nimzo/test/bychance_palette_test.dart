import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';

void main() {
  test('Tingle-reference lavender palette keeps NIMZO identity consistent', () {
    expect(NimzoStyle.primary, const Color(0xffa243f5));
    expect(NimzoStyle.pink, const Color(0xffed428c));
    expect(NimzoStyle.blue, const Color(0xff3a85ff));
    expect(NimzoStyle.orange, const Color(0xffffab21));
    expect(NimzoStyle.royal, const Color(0xff7439d4));
    expect(NimzoStyle.heroGradient.colors, <Color>[
      NimzoStyle.primary,
      NimzoStyle.royal,
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
