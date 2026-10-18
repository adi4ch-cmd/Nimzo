import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/auth/presentation/tingle_login_screen.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('login UI shows only email, Facebook and Google at ${width}dp',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TingleLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tingle-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('tingle-password')), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Quick Log In'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
