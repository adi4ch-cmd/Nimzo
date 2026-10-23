import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';
import 'package:nimzo/features/rooms/treasure/treasure_repository.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('repository accepts the server JSON receipt contract', () async {
    final db = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response(
            '{"box_id":"box-2","coins":1667,"status":"claimed"}', 200,
            request: request, headers: {'content-type': 'application/json'})));
    addTearDown(db.dispose);
    expect(await TreasureRepository(db).claim('box-2', 'room-a'), 1667);
  });
  testWidgets(
      'treasure requires confirmation and retries original funding after lost response',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return requests.length == 1
              ? http.Response('{"message":"unavailable"}', 503)
              : http.Response('{"id":"box-1","status":"replayed"}', 200,
                  request: request,
                  headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('user-a'),
          walletProvider
              .overrideWith((_) async => (coins: 1000000, diamonds: 0)),
          roomTreasuresProvider('room-a').overrideWith((_) => Stream.value([])),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: TreasureSheet(roomId: 'room-a'))))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('Fund treasure box?'), findsOneWidget);
    await tester.tap(find.text('Confirm 10,000 coins'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    await tester.ensureVisible(find.text('Retry same box'));
    await tester.tap(find.text('Retry same box'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(find.text('Treasure box funded.'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'eligible claim shows only server confirmed coins on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/rpc/claim_room_treasure'));
          expect(
              jsonDecode(request.body), {'p_box': 'box-2', 'p_room': 'room-a'});
          return http.Response(
              '{"box_id":"box-2","coins":1667,"status":"claimed"}', 200,
              request: request, headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final box = TreasureBox.fromJson({
      'id': 'box-2',
      'sender_id': 'sender',
      'display_name': 'Room friend',
      'scope': 'room',
      'eligibility': 'all',
      'total_coins': 10000,
      'remaining_coins': 10000,
      'quantity': 6,
      'claimed_count': 0,
      'claimed_coins': null,
      'refunded_coins': 0,
      'expires_at':
          DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      'can_claim': true
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('user-a'),
          walletProvider.overrideWith((_) async => (coins: 1000, diamonds: 0)),
          roomTreasuresProvider('room-a')
              .overrideWith((_) => Stream.value([box]))
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: TreasureSheet(roomId: 'room-a'))))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Claim'));
    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(find.text('1,667 coins received.'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('|'));
    expect(tester.takeException(), isNull);
  });
}
