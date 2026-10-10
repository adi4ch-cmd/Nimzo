import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/vip/phoenix_room_entry.dart';
import 'package:nimzo/features/vip/royal_lion_entry.dart';

void main() {
  test('entry freshness includes time spent waiting for server response', () {
    final born = DateTime.utc(2001);
    expect(
      phoenixEntryIsFresh(
        serverNow: born.add(const Duration(seconds: 3)),
        createdAt: born,
        requestTime: const Duration(seconds: 8),
      ),
      isFalse,
    );
    expect(
      phoenixEntryIsFresh(
        serverNow: born.add(const Duration(seconds: 3)),
        createdAt: born,
        requestTime: const Duration(seconds: 1),
      ),
      isTrue,
    );
    expect(
      phoenixEntryIsFresh(
        serverNow: null,
        createdAt: born,
        requestTime: Duration.zero,
      ),
      isFalse,
    );
  });
  testWidgets(
    'entry ignores history, verifies new arrivals and never replays duplicates',
    (tester) async {
      final events = StreamController<List<Map<String, dynamic>>>();
      var requests = 0;
      Completer<void>? pauseGate;
      final db = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests++;
            if (pauseGate != null) await pauseGate.future;
            return http.Response(
              jsonEncode({
                'vip_level': 10,
                'server_now': '2001-01-01T00:00:00Z',
                'vip_expires_at': '2001-01-01T01:00:00Z',
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      final old = {
        'id': 'old',
        'user_id': 'target',
        'display_name': 'Old arrival',
        'created_at': '2001-01-01T00:00:00Z',
      };
      final fresh = {...old, 'id': 'fresh', 'display_name': 'New arrival'};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWithValue('viewer'),
            phoenixEntriesProvider('room').overrideWith((_) => events.stream),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: PhoenixRoomEntry(roomId: 'room')),
            ),
          ),
        ),
      );
      events.add([old]);
      await tester.pump();
      expect(requests, 0);
      events.add([fresh, old]);
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(
        find.textContaining('THE KING HAS ARRIVED'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 5600));
      events.add([fresh, old]);
      await tester.pump();
      expect(find.byType(RoyalLionEntry), findsNothing);
      expect(requests, 1);
      // A newly delivered stale event is still rejected using server time.
      events.add([
        {...old, 'id': 'stale', 'created_at': '2000-12-31T23:59:40Z'},
        fresh,
        old,
      ]);
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(find.byType(RoyalLionEntry), findsNothing);
      pauseGate = Completer<void>();
      events.add([
        {...old, 'id': 'delayed'},
        fresh,
        old,
      ]);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      pauseGate.complete();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(find.byType(RoyalLionEntry), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      unawaited(events.close());
      await tester.pump();
      await tester.runAsync(db.dispose);
    },
  );
  for (final membership in [
    {'vip_level': 1, 'svip_level': 0, 'expected': 'VIP 1'},
    {'vip_level': 0, 'svip_level': 4, 'expected': 'SVIP 4'},
  ]) {
    testWidgets('a server-verified ${membership['expected']} receives room entry',
        (tester) async {
      final events = StreamController<List<Map<String, dynamic>>>();
      final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response(
          jsonEncode({
            'vip_level': membership['vip_level'],
            'vip_expires_at': '2002-01-01T00:00:00Z',
            'svip_level': membership['svip_level'],
            'svip_expires_at': '2002-01-01T00:00:00Z',
            'server_now': '2001-01-01T00:00:00Z',
          }),
          200, request: request,
          headers: {'content-type': 'application/json'},
        )),
      )))!;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('viewer'),
          phoenixEntriesProvider('room').overrideWith((_) => events.stream),
        ],
        child: const MaterialApp(home: Scaffold(
          body: PhoenixRoomEntry(roomId: 'room'))),
      ));
      events.add([]);
      await tester.pump();
      events.add([{
        'id': 'fresh-${membership['expected']}',
        'user_id': 'target',
        'display_name': 'Verified member',
        'created_at': '2001-01-01T00:00:00Z',
      }]);
      await tester.pump();
      await tester.runAsync(() async =>
        Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
      expect(find.byKey(const ValueKey('verified-premium-room-entry')),
        findsOneWidget);
      expect(find.text('${membership['expected']} · VERIFIED ENTRY'),
        findsOneWidget);
      expect(find.byType(RoyalLionEntry), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      // A listened realtime stream may never finish its close Future in\n      // fake-async widget tests; disposal removes the subscription.\n      unawaited(events.close());
      await tester.runAsync(db.dispose);
    });
  }

}
