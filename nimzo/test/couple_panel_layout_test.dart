import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/profile/profile_presentation.dart';

void main() {
  testWidgets('linked CP panel bounds long partner names', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
            body: SizedBox(
                width: 320,
                child: CouplePanel(
                    name: 'Amina',
                    partner:
                        'A very long partner display name that must fit')))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('unlinked CP panel stays bounded with two-line Add CP label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
            body: SizedBox(width: 320, child: CouplePanel(name: 'Amina')))));
    await tester.pumpAndSettle();
  });
}
