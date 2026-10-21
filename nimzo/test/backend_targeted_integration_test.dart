import 'package:nimzo/features/gifts/gift_repository.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/rooms/presentation/room_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/data/room_chat_repository.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/voice/voice_controller.dart';

import 'remaining_visual_qa_test.dart'
    show FixtureRoomRepository, FixtureVoice, fixtureRoom;

SupabaseClient backendClient(http.Response Function(http.Request) reply) =>
    SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final response = reply(request);
        return http.Response(
          response.body,
          response.statusCode,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

void main() {
  for (final staleMembership in [false, true]) {
    testWidgets(
      'server-visible room chat is readable with staleMembership=$staleMembership when the phone clock is ahead',
      (tester) async {
        final db = (await tester.runAsync(
          () async => backendClient(
            (request) => http.Response(
              staleMembership &&
                      request.url.path.endsWith('/phoenix_membership')
                  ? jsonEncode({
                      'vip_level': 6,
                      'server_now': '2001-01-01T00:00:00Z',
                      'vip_expires_at': '2002-01-01T00:00:00Z',
                    })
                  : '[]',
              200,
            ),
          ),
        ))!;
        addTearDown(() => tester.runAsync(db.dispose));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedGiftAnimationProvider.overrideWith(
                (ref, args) => const Stream.empty(),
              ),
              supabaseProvider.overrideWithValue(db),
              currentUserIdProvider.overrideWithValue('me'),
              roomRepositoryProvider.overrideWithValue(
                FixtureRoomRepository(db),
              ),
              roomDiamondEventsProvider('room')
                  .overrideWith((_) => const Stream.empty()),
              roomDiamondStatusProvider('room').overrideWith(
                (_) async => RoomDiamondStatus(
                  totalCoins: 0,
                  completedStages: 0,
                  progress: 0,
                  cycleStart: DateTime.utc(2026, 10, 9, 20),
                  serverNow: DateTime.utc(2026, 10, 9, 21),
                  resetAt: DateTime.utc(2026, 10, 10, 20),
                ),
              ),
              voiceServiceProvider.overrideWithValue(FixtureVoice()),
              roomProvider('room').overrideWith((_) async => fixtureRoom),
              seatsProvider('room').overrideWith((_) => Stream.value([])),
              roomSeatProfilesProvider('room').overrideWith((_) async => {}),
              onlineCountProvider('room').overrideWith((_) => Stream.value(1)),
              roomChatProvider('room').overrideWith(
                (_) => Stream.value([
                  RoomMessage(
                    'server',
                    'other',
                    'Visible according to server RLS',
                    DateTime.utc(2000),
                  ),
                ]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const RoomScreen(roomId: 'room'),
            ),
          ),
        );
        await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Visible according to server RLS'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.text('Visible according to server RLS'))
              .style
              ?.color,
          NimzoStyle.ink,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  test(
    'profile retains authoritative totals without inventing level thresholds',
    () {
      final p = Profile.fromJson({
        'id': 'me',
        'nimzo_id': 11699311,
        'wealth_coins': 9007199254740993,
        'charm_diamonds': 450,
        'active_points': 0,
      });
      expect(p.wealthCoins, 9007199254740993);
      expect(p.charmDiamonds, 450);
      expect(p.activePoints, 0);
      expect(p.wealthLevel, 0);
      final unavailable = Profile.fromJson({'id': 'me', 'nimzo_id': 11699311});
      expect(unavailable.wealthCoins, isNull);
      expect(unavailable.activePoints, isNull);
    },
  );
  for (final kind in ['wealth', 'charm', 'room']) {
    for (final period in ['weekly', 'monthly']) {
      test(
        'supported $kind/$period forwards the exact live RPC contract',
        () async {
          final db = backendClient((request) {
            expect(request.url.path, '/rest/v1/rpc/leaderboard');
            expect(jsonDecode(request.body), {
              'p_kind': kind,
              'p_period': period,
              'p_limit': 10,
            });
            return http.Response(
              '[{"id":"actual","name":"Actual","score":450}]',
              200,
            );
          });
          addTearDown(db.dispose);
          expect(
            (await LeaderboardRepository(db).top(kind, period)).single['score'],
            450,
          );
        },
      );
    }
  }
  test(
    'unsupported ranking combinations do not silently call another window',
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
        ('active', 'monthly'),
      ]) {
        await expectLater(
          LeaderboardRepository(db).top(pair.$1, pair.$2),
          throwsArgumentError,
        );
      }
      expect(calls, 0);
    },
  );
}
