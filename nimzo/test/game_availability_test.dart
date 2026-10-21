import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/features/games/dynamic_game_catalog.dart';
import 'package:nimzo/features/games/games_catalog_screen.dart';

void main() {
  testWidgets(
      'catalog exposes existing server games and labels practice honestly',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [nimzoLiveGameFlagsProvider.overrideWith((_) async => const {})],
      child: const MaterialApp(home: GamesCatalogScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('game-catalog-fruit_party')), 400,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.byKey(const ValueKey('game-catalog-fruit_party')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('game-catalog-fruit_wheel')), findsOneWidget);
    expect(find.text('Practice'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
