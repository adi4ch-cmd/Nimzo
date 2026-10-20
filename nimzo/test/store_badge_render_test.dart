import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_equipped_frame.dart';

void main() {
  testWidgets('Royal Badge stays hidden until equipped', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NimzoEquippedRoyalBadge()),
    ));
    expect(find.byKey(const ValueKey('equipped-nimzo-royal-badge')),
        findsNothing);
  });

  testWidgets('Equipped Royal Badge is visible on a user profile',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NimzoEquippedRoyalBadge(variant: 3)),
    ));
    expect(find.byKey(const ValueKey('equipped-nimzo-royal-badge')),
        findsOneWidget);
    expect(find.text('ROYAL'), findsOneWidget);
  });
}
