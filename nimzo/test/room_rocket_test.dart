// ignore_for_file: prefer_collection_literals, prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_playback.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_widgets.dart';

void main() {
  test('six approved Rocket levels map one-to-one to distinct VAP clips', () {
    expect(roomRocketTargets, [
      5000000, 10000000, 20000000, 30000000, 50000000, 100000000,
    ]);
    expect([
      for (var i = 0; i < 6; i++) rocketRewardPath(i)
    ].toSet().length, 6);
    expect(rocketRewardPath(0), endsWith('vap_rocket_reward_1.mp4'));
    expect(rocketRewardPath(5), endsWith('vap_rocket_reward_6.mp4'));
    expect(() => rocketRewardPath(-1), throwsRangeError);
    expect(() => rocketRewardPath(6), throwsRangeError);
  });

  testWidgets('Rocket progress uses existing server-signed status, not fake UI data',
      (tester) async {
    final now = DateTime.utc(2026, 10, 10, 20);
    final current = RoomDiamondStatus(
      totalCoins: 15000000,
      completedStages: 2,
      progress: .5,
      cycleStart: now,
      resetAt: now.add(const Duration(days: 1)),
      serverNow: now,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roomDiamondStatusProvider('room').overrideWith((_) async => current),
      ],
      child: const MaterialApp(home: Scaffold(
        body: SingleChildScrollView(child: RoomRocketSheet(roomId: 'room')),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ROOM ROCKET'), findsOneWidget);
    expect(find.textContaining('15.0M gifted'), findsOneWidget);
    expect(find.textContaining('Rocket 3'), findsOneWidget);
    expect(find.textContaining('Diamond Blast'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    ).value, .5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settled 6-stage Rocket events queue exactly once in server order',
      (tester) async {
    final events = StreamController<DiamondUpdate>.broadcast(sync: true);
    addTearDown(events.close);
    final now = DateTime.utc(2026, 10, 10, 20);
    final status = RoomDiamondStatus(
      totalCoins: 30000000, completedStages: 4, progress: 0,
      cycleStart: now, resetAt: now.add(const Duration(days: 1)),
      serverNow: now,
    );
    var micTaps = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roomDiamondStatusProvider('room').overrideWith((_) async => status),
        roomDiamondEventsProvider('room').overrideWith((_) => events.stream),
      ],
      child: MaterialApp(home: RoomRocketHost(
        enabled: true,
        roomId: 'room',
        playbackBuilder: (event, _) =>
          Text('Verified Rocket ' + event.stage.toString()),
        child: Scaffold(body: Center(child: TextButton(
          onPressed: () => micTaps++,
          child: const Text('Mic'),
        ))),
      )),
    ));
    await tester.pumpAndSettle();
    final one = DiamondBlastEvent(
      id: 'one', roomId: 'room', stage: 0, cycleStart: now);
    events.add(DiamondUpdate(1, one));
    events.add(DiamondUpdate(2, one));
    events.add(DiamondUpdate(3, DiamondBlastEvent(
      id: 'two', roomId: 'room', stage: 1, cycleStart: now)));
    await tester.pump();
    expect(find.text('Verified Rocket 0'), findsOneWidget);
    await tester.tap(find.text('Mic'));
    expect(micTaps, 1);
    await tester.tap(find.byTooltip('Skip rocket animation'));
    await tester.pump();
    expect(find.text('Verified Rocket 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Skip rocket animation'));
    await tester.pump();
    expect(find.textContaining('Verified Rocket'), findsNothing);
    events.add(DiamondUpdate(4, one));
    await tester.pump();
    expect(find.textContaining('Verified Rocket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rocket progress explains verified giving and daily reset',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: Scaffold(
        body: RoomRocketSheet(),
      ))),
    );
    expect(find.textContaining('verified', findRichText: true), findsNothing);
    expect(find.textContaining('Verified gifts only'), findsOneWidget);
    expect(find.textContaining('11:00 p.m.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
