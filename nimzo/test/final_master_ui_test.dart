import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_screen.dart';

void main() {
  testWidgets('Bigetar renders final multipliers and marque markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameScreen(slug: 'bigetar', roomId: 'room'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BM'), findsOneWidget);
    expect(find.text('66x'), findsOneWidget);
    expect(find.text('Results unavailable'), findsOneWidget);
  });
}
