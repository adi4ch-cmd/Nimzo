import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/room_game_host.dart';
import 'package:nimzo/features/games/game_screen.dart';

void main() {
  testWidgets('minimize and restore retain room and game state',
      (tester) async {
    var microphoneActions = 0;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = GlobalKey<RoomGameHostState>();
    final room = GlobalKey();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: RoomGameHost(
      key: host,
      roomId: 'room',
      voiceConnected: true,
      onMic: () => microphoneActions++,
      child: Scaffold(body: Text('Room chat', key: room)),
    ))));
    final roomElement = room.currentContext;
    host.currentState!.open('fruit_party_jackpot');
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    await tester.tap(find.byTooltip('Enable microphone'));
    expect(microphoneActions, 1);
    expect(tester.getTopLeft(find.byType(GameScreen)).dy, closeTo(224, 1));
    expect(tester.takeException(), isNull);
    final gameState = tester.state(find.byType(GameScreen));
    await tester.tap(find.byTooltip('Expand game'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(GameScreen)).dy, 0);
    expect(tester.state(find.byType(GameScreen)), same(gameState));
    expect(room.currentContext, same(roomElement));
    await tester.tap(find.byTooltip('Collapse game'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(GameScreen)).dy, closeTo(224, 1));
    await tester.tap(find.byTooltip('Return to voice room'));
    await tester.pumpAndSettle();
    expect(find.text('Room chat'), findsOneWidget);
    expect(room.currentContext, same(roomElement));
    await tester.tap(find.text('Restore game'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(GameScreen)), same(gameState));
    await tester.tap(find.byTooltip('Close game'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(room.currentContext, same(roomElement));
  });
}
