import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_level_screen.dart';

void main() {
  testWidgets('verified game level shows progress and correct artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLevelProvider.overrideWith(
            (_) async => {'level': 3, 'rounds_played': 7, 'next_rounds': 10},
          ),
        ],
        child: const MaterialApp(home: GameLevelScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Game Level 3'), findsOneWidget);
    expect(find.text('7 verified rounds played'), findsOneWidget);
    expect(find.text('3 more settled rounds to next level'), findsOneWidget);
    expect(find.text('LV 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('max game level has no fake next target', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameLevelProvider.overrideWith(
            (_) async => {
              'level': 15,
              'rounds_played': 130,
              'next_rounds': null,
            },
          ),
        ],
        child: const MaterialApp(home: GameLevelScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Highest game level reached'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
