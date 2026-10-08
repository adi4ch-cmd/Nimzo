import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';
import 'package:nimzo/features/games/game_screen.dart';

void main() {
  for (final g in NimzoRoomGames.approved) {
    for (final textScale in [1.0, 1.8]) {
      testWidgets(
          '${g.title} stays bounded at text scale $textScale without fake results',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!),
                home: GameScreen(slug: g.slug, roomId: 'room'))));
        await tester.pumpAndSettle();
        expect(find.text('Game service unavailable'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Results unavailable'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Results unavailable'), findsOneWidget);
        expect(find.textContaining('You won'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
