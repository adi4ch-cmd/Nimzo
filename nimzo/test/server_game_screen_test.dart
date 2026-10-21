import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/games/game_screen.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'server coin game retries original wager and renders only confirmed result',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (requests.length == 1)
            return http.Response('{"message":"temporarily unavailable"}', 503,
                request: request);
          return http.Response(
              jsonEncode({
                'bet_id': 'bet-1',
                'status': 'won',
                'payout': 200,
                'result': {
                  'grid': List.filled(25, 'lemon'),
                  'counts': {'lemon': 25}
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request);
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('user'),
          walletProvider.overrideWith((_) async => (coins: 1000, diamonds: 0)),
        ],
        child: const MaterialApp(
            home: GameScreen(slug: 'fruit_party', roomId: 'room'))));
    await tester.pumpAndSettle();
    expect(find.text('Fruit Party'), findsOneWidget);
    expect(find.textContaining('Payout:'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('server-game-play')));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.text('Retry same round'), findsOneWidget);
    await tester.tap(find.text('Retry same round'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(find.text('Payout: 200 coins'), findsOneWidget);
    expect(find.text('Round receipt: bet-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coin game outside a room cannot submit a wager', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: GameScreen(slug: 'fruit_wheel'))));
    await tester.pumpAndSettle();
    expect(find.text('Join a voice room to play with coins.'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-game-play')), findsNothing);
  });
}
