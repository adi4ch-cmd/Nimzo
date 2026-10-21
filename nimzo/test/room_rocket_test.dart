// ignore_for_file: prefer_collection_literals, prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_playback.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_leaderboard.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_widgets.dart';

void main() {
  test(
      'silent VAP phases have original non-silent PCM sound; AAC rewards stay native',
      () {
    for (var stage = 0; stage < 6; stage++) {
      expect(rocketSoundPath(stage, reward: false),
          endsWith('nimzo_rocket_launch.wav'));
      expect(rocketSoundPath(stage, reward: true),
          stage < 3 ? endsWith('nimzo_rocket_reward.wav') : isNull);
    }
    for (final reward in [false, true]) {
      final data = File(rocketSoundPath(0, reward: reward)!).readAsBytesSync();
      expect(String.fromCharCodes(data.take(4)), 'RIFF');
      expect(String.fromCharCodes(data.skip(8).take(4)), 'WAVE');
      final bytes = ByteData.sublistView(data);
      expect(bytes.getUint16(22, Endian.little), 1);
      expect(bytes.getUint32(24, Endian.little), 22050);
      expect(bytes.getUint16(34, Endian.little), 16);
      var energy = 0;
      for (var i = 44; i < data.length; i += 2) {
        final sample = bytes.getInt16(i, Endian.little);
        energy += sample * sample;
      }
      expect(energy / ((data.length - 44) / 2), greaterThan(100000));
    }
  });

  test('six approved Rocket levels map one-to-one to distinct VAP clips', () {
    expect(roomRocketTargets, [
      5000000,
      10000000,
      20000000,
      30000000,
      50000000,
      100000000,
    ]);
    expect([for (var i = 0; i < 6; i++) rocketRewardPath(i)].toSet().length, 6);
    expect(rocketFlyPath(0), endsWith('vap_rocket_fly_1.mp4'));
    expect(rocketFlyPath(5), endsWith('vap_rocket_fly_6.mp4'));
    expect(() => rocketFlyPath(6), throwsRangeError);
    expect(rocketRewardPath(0), endsWith('vap_rocket_reward_1.mp4'));
    expect(rocketRewardPath(5), endsWith('vap_rocket_reward_6.mp4'));
    expect(() => rocketRewardPath(-1), throwsRangeError);
    expect(() => rocketRewardPath(6), throwsRangeError);
  });

  testWidgets(
      'Rocket progress uses existing server-signed status, not fake UI data',
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
        roomRocketLeaderboardProvider('room').overrideWith((_) async => []),
      ],
      child: const MaterialApp(
          home: Scaffold(
        body: SingleChildScrollView(child: RoomRocketSheet(roomId: 'room')),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ROOM ROCKET'), findsOneWidget);
    expect(find.textContaining('15.0M gifted'), findsOneWidget);
    expect(find.textContaining('Rocket 3'), findsOneWidget);
    expect(find.textContaining('Diamond Blast'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5);
    expect(find.byKey(const ValueKey('six-rocket-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('rocket-stage-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rocket-stage-5')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rocket-stage-5')));
    await tester.pumpAndSettle();
    expect(find.text('ROCKET 6'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('rocket-ranking-heading')));
    await tester.pumpAndSettle();
    expect(find.text('Gifting Top 1–3'), findsOneWidget);
    expect(find.byKey(const ValueKey('rocket-rewards-tab')), findsNothing);
    expect(find.text('Prize not configured'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'settled 6-stage Rocket events queue exactly once in server order',
      (tester) async {
    final events = StreamController<DiamondUpdate>.broadcast(sync: true);
    addTearDown(events.close);
    final now = DateTime.utc(2026, 10, 10, 20);
    final status = RoomDiamondStatus(
      totalCoins: 30000000,
      completedStages: 4,
      progress: 0,
      cycleStart: now,
      resetAt: now.add(const Duration(days: 1)),
      serverNow: now,
    );
    var micTaps = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roomDiamondStatusProvider('room').overrideWith((_) async => status),
        roomDiamondEventsProvider('room').overrideWith((_) => events.stream),
      ],
      child: MaterialApp(
          home: RoomRocketHost(
        enabled: true,
        roomId: 'room',
        playbackBuilder: (event, _) =>
            Text('Verified Rocket ' + event.stage.toString()),
        child: Scaffold(
            body: Center(
                child: TextButton(
          onPressed: () => micTaps++,
          child: const Text('Mic'),
        ))),
      )),
    ));
    await tester.pumpAndSettle();
    final one =
        DiamondBlastEvent(id: 'one', roomId: 'room', stage: 0, cycleStart: now);
    events.add(DiamondUpdate(1, one));
    events.add(DiamondUpdate(2, one));
    events.add(DiamondUpdate(
        3,
        DiamondBlastEvent(
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
    events.add(DiamondUpdate(
        5,
        DiamondBlastEvent(
            id: 'three', roomId: 'room', stage: 2, cycleStart: now)));
    await tester.pump();
    expect(find.text('Verified Rocket 2'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining('Verified Rocket'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('Verified Rocket'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rocket progress explains verified giving and daily reset',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
          child: MaterialApp(
              home: Scaffold(
        body: RoomRocketSheet(),
      ))),
    );
    expect(find.textContaining('verified', findRichText: true), findsNothing);
    expect(find.textContaining('Verified gifts only'), findsOneWidget);
    expect(find.textContaining('11:00 p.m.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
