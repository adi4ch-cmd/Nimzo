import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';

void main() {
  test('NIMZO green and white foundation keeps white action labels readable',
      () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, const Color(0xff087f5b));
    expect(theme.scaffoldBackgroundColor, const Color(0xfff5faf7));
    expect(theme.colorScheme.surface, Colors.white);
    final contrast = (Colors.white.computeLuminance() + .05) /
        (theme.colorScheme.primary.computeLuminance() + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
  });
}
