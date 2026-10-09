import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_widgets.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';

class ProgressRepository extends RoomDiamondRepository {
  ProgressRepository(super.db);
  int coins = 0;
  @override
  Future<RoomDiamondStatus> status(String roomId) async {
    final completed = diamondTargets.where((target) => coins >= target).length;
    final stage = completed.clamp(0, 5);
    final previous = stage == 0 ? 0 : diamondTargets[stage - 1];
    final now = DateTime.utc(2026, 10, 9, 20);
    return RoomDiamondStatus(
        totalCoins: coins,
        completedStages: completed,
        progress: ((coins - previous) / (diamondTargets[stage] - previous))
            .clamp(0.0, 1.0),
        cycleStart: now,
        serverNow: now,
        resetAt: now.add(const Duration(days: 1)));
  }
}

void main() {
  testWidgets(
      'Diamond Blast exposes six approved cumulative targets without fake progress',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home:
                Scaffold(body: SingleChildScrollView(child: CrystalSheet())))));
    for (final target in ['5M', '10M', '20M', '30M', '50M', '100M']) {
      expect(find.text(target), findsOneWidget);
    }
    expect(find.text('Join a room to view live progress.'), findsOneWidget);
    expect(find.textContaining('no wallet rewards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'room blast queue deduplicates events and preserves microphone controls',
      (tester) async {
    final events = StreamController<DiamondUpdate>();
    addTearDown(events.close);
    final now = DateTime.utc(2026, 10, 9, 20);
    final status = RoomDiamondStatus(
        totalCoins: 10000000,
        completedStages: 2,
        progress: 0,
        cycleStart: now,
        serverNow: now,
        resetAt: now.add(const Duration(days: 1)));
    var micTaps = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          roomDiamondEventsProvider('room').overrideWith((_) => events.stream),
          roomDiamondStatusProvider('room').overrideWith((_) async => status),
        ],
        child: MaterialApp(
            home: RoomDiamondHost(
                roomId: 'room',
                enabled: true,
                child: Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: () => micTaps++,
                            child: const Text('Mic'))))))));
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
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Diamond 1 complete!'), findsOneWidget);
    await tester.tap(find.text('Mic'));
    await tester.pump();
    expect(micTaps, 1);
    await tester.tap(find.byTooltip('Skip diamond blast'));
    await tester.pump();
    expect(find.textContaining('Diamond 2 complete!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(DiamondBurst), findsNothing);
    events.add(DiamondUpdate(4, one));
    await tester.pump();
    expect(find.byType(DiamondBurst), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
      'server Diamond Blast model rejects unsupported targets and forged stage payloads',
      () {
    final row = <String, dynamic>{
      'total_coins': 5000000,
      'completed_stages': 1,
      'active_stage': 1,
      'progress': 0.0,
      'thresholds': diamondTargets,
      'cycle_start': '2026-10-09T20:00:00Z',
      'reset_at': '2026-10-10T20:00:00Z',
      'server_now': '2026-10-09T21:00:00Z'
    };
    expect(RoomDiamondStatus.fromJson(row).completedStages, 1);
    expect(
        () => RoomDiamondStatus.fromJson({
              ...row,
              'thresholds': [1, 2, 3, 4, 5, 6]
            }),
        throwsFormatException);
    expect(
        () => DiamondBlastEvent.fromJson({
              'id': 'bad',
              'room_id': 'room',
              'stage': 6,
              'target_coins': 100000000,
              'cycle_start': row['cycle_start']
            }),
        throwsFormatException);
  });
  testWidgets(
      'subthreshold and post-final settled gifts refresh real progress without a blast',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = ProgressRepository(db);
    final events = StreamController<DiamondUpdate>();
    addTearDown(events.close);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          roomDiamondRepositoryProvider.overrideWithValue(repo),
          roomDiamondEventsProvider('room').overrideWith((_) => events.stream),
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomDiamondSheet(roomId: 'room')))));
    await tester.pumpAndSettle();
    expect(find.text('0 coins gifted today'), findsOneWidget);
    repo.coins = 1000000;
    events.add(const DiamondUpdate(1));
    await tester.pumpAndSettle();
    expect(find.text('1.0M coins gifted today'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .2);
    expect(find.byType(DiamondBurst), findsNothing);
    repo.coins = 120000000;
    events.add(const DiamondUpdate(2));
    await tester.pumpAndSettle();
    expect(find.text('120.0M coins gifted today'), findsOneWidget);
    expect(find.text('All six diamonds completed!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('six-stage live progress has a reviewed phone screenshot',
      (tester) async {
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(
              File('test/fonts/Roboto-Regular.ttf').readAsBytesSync()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 10, 9, 20);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          roomDiamondStatusProvider('room').overrideWith((_) async =>
              RoomDiamondStatus(
                  totalCoins: 15000000,
                  completedStages: 2,
                  progress: .5,
                  cycleStart: now,
                  serverNow: now,
                  resetAt: now.add(const Duration(days: 1)))),
        ],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: RepaintBoundary(
                key: key,
                child: Scaffold(
                    appBar: AppBar(title: const Text('Diamond Blast')),
                    body: const SingleChildScrollView(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CrystalSheet(roomId: 'room'))))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byKey(key), matchesGoldenFile('goldens/diamond_blast_live.png'));
  });
  testWidgets(
      'a new server cycle clears queued old blasts before status refresh completes',
      (tester) async {
    final events = StreamController<DiamondUpdate>();
    addTearDown(events.close);
    final cycle = DateTime.utc(2026, 10, 9, 20);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          roomDiamondEventsProvider('room').overrideWith((_) => events.stream),
          roomDiamondStatusProvider('room').overrideWith((_) async =>
              RoomDiamondStatus(
                  totalCoins: 0,
                  completedStages: 0,
                  progress: 0,
                  cycleStart: cycle,
                  serverNow: cycle,
                  resetAt: cycle.add(const Duration(days: 1)))),
        ],
        child: const MaterialApp(
            home: RoomDiamondHost(
                roomId: 'room',
                enabled: true,
                child: Scaffold(body: Text('Room'))))));
    await tester.pumpAndSettle();
    events.add(DiamondUpdate(
        1,
        DiamondBlastEvent(
            id: 'old-one', roomId: 'room', stage: 0, cycleStart: cycle)));
    events.add(DiamondUpdate(
        2,
        DiamondBlastEvent(
            id: 'old-two', roomId: 'room', stage: 1, cycleStart: cycle)));
    await tester.pump();
    events.add(DiamondUpdate(
        3,
        DiamondBlastEvent(
            id: 'new-one',
            roomId: 'room',
            stage: 0,
            cycleStart: cycle.add(const Duration(days: 1)))));
    await tester.pump();
    expect(tester.widget<DiamondBurst>(find.byType(DiamondBurst)).event.id,
        'new-one');
    await tester.pumpAndSettle();
    expect(find.byType(DiamondBurst), findsNothing);
  });
}
