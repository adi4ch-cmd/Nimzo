import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';
import 'package:nimzo/features/vip/vip_progress.dart';
import 'package:nimzo/features/vip/vip_repository.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/rooms/presentation/room_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/data/room_chat_repository.dart';
import 'package:nimzo/features/voice/voice_controller.dart';
import 'remaining_visual_qa_test.dart'
    show FixtureRoomRepository, FixtureVoice, fixtureRoom;

SupabaseClient backendClient(http.Response Function(http.Request) reply) =>
    SupabaseClient('https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final response = reply(request);
      return http.Response(response.body, response.statusCode,
          request: request, headers: {'content-type': 'application/json'});
    }));

void main() {
  for (final (active, cents) in [(true, 20000), (false, 0), (false, 2500)]) {
    test('SVIP progress consumes server cycle active=$active cents=$cents',
        () async {
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('me'),
        vipStatusProvider.overrideWith((_) async => {
              'svip_cycle_cents': cents,
              'svip_cycle_active': active,
            }),
        svipThresholdsProvider.overrideWith((_) async => {1: 5000, 2: 50000}),
      ]);
      addTearDown(container.dispose);
      final progress = await container.read(svipProgressProvider.future);
      expect(progress.cycleCents, cents);
      expect(
          progress.fraction,
          cents == 0
              ? 0
              : cents == 2500
                  ? .5
                  : .4);
    });
  }
  test('old status contract cannot present stale recharge as current progress',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      vipStatusProvider.overrideWith((_) async => {'svip_level': 0}),
      svipThresholdsProvider.overrideWith((_) async => {1: 5000}),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(svipProgressProvider.future), throwsStateError);
  });
  test(
      'progress handles simultaneous data/catalog failure without leaking a future error',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      vipStatusProvider
          .overrideWith((_) async => throw StateError('Status unavailable')),
      svipThresholdsProvider
          .overrideWith((_) async => throw StateError('Catalog unavailable')),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(svipProgressProvider.future), throwsA(isA<Object>()));
  });
  testWidgets(
      'server-visible room chat is retained when the phone clock is ahead',
      (tester) async {
    final db = (await tester
        .runAsync(() async => backendClient((_) => http.Response('[]', 200))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('me'),
          roomRepositoryProvider.overrideWithValue(FixtureRoomRepository(db)),
          voiceServiceProvider.overrideWithValue(FixtureVoice()),
          roomProvider('room').overrideWith((_) async => fixtureRoom),
          seatsProvider('room').overrideWith((_) => Stream.value([])),
          roomSeatProfilesProvider('room').overrideWith((_) async => {}),
          onlineCountProvider('room').overrideWith((_) => Stream.value(1)),
          roomChatProvider('room').overrideWith((_) => Stream.value([
                RoomMessage('server', 'other',
                    'Visible according to server RLS', DateTime.utc(2000)),
              ])),
        ],
        child: MaterialApp(
            theme: AppTheme.light(), home: const RoomScreen(roomId: 'room'))));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Visible according to server RLS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  test(
      'profile retains authoritative totals without inventing level thresholds',
      () {
    final p = Profile.fromJson({
      'id': 'me',
      'nimzo_id': 11699311,
      'wealth_coins': 9007199254740993,
      'charm_diamonds': 450,
      'active_points': 0,
      'svip_cycle_cents': 20000,
      'svip_cycle_start': '2026-10-01T00:00:00Z'
    });
    expect(p.wealthCoins, 9007199254740993);
    expect(p.charmDiamonds, 450);
    expect(p.activePoints, 0);
    expect(p.wealthLevel, 0);
    expect(p.svipCycleCents, 20000);
    final unavailable = Profile.fromJson({'id': 'me', 'nimzo_id': 11699311});
    expect(unavailable.wealthCoins, isNull);
    expect(unavailable.activePoints, isNull);
  });
  for (final kind in ['wealth', 'charm', 'room']) {
    for (final period in ['weekly', 'monthly']) {
      test('supported $kind/$period forwards the exact live RPC contract',
          () async {
        final db = backendClient((request) {
          expect(request.url.path, '/rest/v1/rpc/leaderboard');
          expect(jsonDecode(request.body),
              {'p_kind': kind, 'p_period': period, 'p_limit': 10});
          return http.Response(
              '[{"id":"actual","name":"Actual","score":450}]', 200);
        });
        addTearDown(db.dispose);
        expect(
            (await LeaderboardRepository(db).top(kind, period)).single['score'],
            450);
      });
    }
  }
  test('unsupported ranking combinations do not silently call another window',
      () async {
    var calls = 0;
    final db = backendClient((_) {
      calls++;
      return http.Response('[]', 200);
    });
    addTearDown(db.dispose);
    for (final pair in [
      ('wealth', 'daily'),
      ('gift', 'weekly'),
      ('active', 'monthly')
    ]) {
      await expectLater(
          LeaderboardRepository(db).top(pair.$1, pair.$2), throwsArgumentError);
    }
    expect(calls, 0);
  });
  test('SVIP progress uses live cents/catalog and does not invent tiers 9–10',
      () {
    final progress = SvipProgress(
        cycleCents: 20000, thresholds: {1: 5000, 2: 50000, 3: 200000});
    expect(progress.nextLevel, 2);
    expect(progress.nextThresholdCents, 50000);
    expect(progress.fraction, .4);
    expect(progress.thresholdFor(10), isNull);
    expect(
        progress.cycleCents, 20000); // No conversion from a visual tier index.
  });
  test('catalog values are read from the deployed table, not the UI catalog',
      () async {
    final db = backendClient((request) {
      expect(request.url.path, '/rest/v1/svip_thresholds');
      return http.Response(
          '[{"level":1,"usd_cents":5000},{"level":2,"usd_cents":50000}]', 200);
    });
    addTearDown(db.dispose);
    expect(await VipRepository(db).svipThresholds(), {1: 5000, 2: 50000});
  });
  test('a missing VIP status is a clear missing-account failure', () async {
    final db = backendClient((_) => http.Response('null', 200));
    addTearDown(db.dispose);
    await expectLater(VipRepository(db).status(), throwsStateError);
  });
}
