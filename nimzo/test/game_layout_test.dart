import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';
import 'package:nimzo/features/games/game_screen.dart';

void main() {
  for (final g in NimzoRoomGames.approved) {
    testWidgets(
        '${g.title} stays bounded on a small phone without fake results',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          MaterialApp(home: GameScreen(slug: g.slug, roomId: 'room')));
      await tester.pumpAndSettle();
      expect(find.text('Results unavailable'), findsOneWidget);
      expect(find.textContaining('You won'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
