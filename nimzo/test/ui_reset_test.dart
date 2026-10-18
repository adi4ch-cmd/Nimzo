import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('NIMZO reference onboarding replaces the retired blank UI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('nimzo-ui-reset-blank')), findsNothing);
    expect(find.text('NIMZO'), findsOneWidget);
    expect(find.text('Speak. Connect. Celebrate.'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
