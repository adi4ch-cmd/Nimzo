import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_leaderboard.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SilentRepository extends RoomDiamondRepository {
  SilentRepository()
      : super(SupabaseClient('https://example.supabase.co', 'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  int calls = 0;
  @override
  Stream<DiamondUpdate> changes(String roomId) => const Stream.empty();
  @override
  Future<RoomDiamondStatus> status(String roomId) async {
    calls++;
    final now = DateTime.utc(2026, 10, 21, 20);
    return RoomDiamondStatus(
      totalCoins: calls * 100,
      completedStages: 0,
      progress: 0,
      cycleStart: now,
      serverNow: now,
      resetAt: now.add(const Duration(days: 1)),
    );
  }
}

void main() {
  test('history reads persisted milestones with room filter and stable order',
      () async {
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/room_diamond_blast_events');
      expect(request.url.queryParameters['room_id'], 'eq.room');
      expect(
          request.url.queryParameters['order'], 'created_at.desc.nullslast,stage.desc.nullslast');
      expect(request.url.queryParameters['limit'], '60');
      return http.Response(
          jsonEncode([
            {
              'id': 'event',
              'room_id': 'room',
              'stage': 4,
              'target_coins': 50000000,
              'cycle_start': '2026-10-20T20:00:00Z',
              'created_at': '2026-10-21T10:15:00Z',
            }
          ]),
          200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    final events = await RoomDiamondRepository(client).history('room');
    expect(events.single.stage, 4);
    expect(events.single.createdAt, DateTime.utc(2026, 10, 21, 10, 15));
    await client.dispose();
  });

  testWidgets('status recovers a missed subthreshold gift without realtime', (
    tester,
  ) async {
    final repository = SilentRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomDiamondRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final value =
                  ref.watch(roomDiamondStatusProvider('room')).valueOrNull;
              return Text('${value?.totalCoins}');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('100'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('200'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reset countdown advances without another gift', (tester) async {
    final now = DateTime.utc(2026, 10, 21, 20);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomDiamondStatusProvider('room').overrideWith(
            (_) async => RoomDiamondStatus(
              totalCoins: 0,
              completedStages: 0,
              progress: 0,
              cycleStart: now,
              serverNow: now,
              resetAt: now.add(const Duration(minutes: 2)),
            ),
          ),
          roomRocketLeaderboardProvider('room').overrideWith((_) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RoomRocketSheet(roomId: 'room')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milestone history'), findsOneWidget);
    expect(find.text('Reset countdown: 0:02'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Reset countdown: 0:01'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
