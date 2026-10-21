import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';
import 'package:nimzo/features/discover/ranking_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final kind in ['wealth', 'charm']) {
    for (final period in ['daily', 'weekly', 'monthly', 'all_time']) {
      test('$kind/$period requests exact server ranking without synthetic rows',
          () async {
        final db = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(request.url.path, '/rest/v1/rpc/leaderboard');
            expect(jsonDecode(request.body),
                {'p_kind': kind, 'p_period': period, 'p_limit': 10});
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }),
        );
        addTearDown(db.dispose);
        expect(await LeaderboardRepository(db).top(kind, period), isEmpty);
      });
    }
  }
  test('ranking limits are rejected before making a network request', () async {
    var calls = 0;
    final db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(db.dispose);
    for (final limit in [0, -1, 101]) {
      await expectLater(
          LeaderboardRepository(db).top('wealth', 'weekly', limit: limit),
          throwsArgumentError);
    }
    expect(calls, 0);
  });
  testWidgets(
      'both gift categories expose daily weekly monthly and all time at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <(String, String)>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        leaderboardProvider.overrideWith((ref, key) async {
          requests.add(key);
          return [];
        })
      ],
      child: const MaterialApp(home: RankingScreen()),
    ));
    await tester.pumpAndSettle();
    for (final category in [('Wealth', 'wealth'), ('Charm', 'charm')]) {
      await tester.tap(find.text(category.$1));
      await tester.pumpAndSettle();
      for (final period in [
        ('Daily', 'daily'),
        ('Weekly', 'weekly'),
        ('Monthly', 'monthly'),
        ('All Time', 'all_time')
      ]) {
        await tester.tap(find.text(period.$1));
        await tester.pumpAndSettle();
        expect(requests, contains((category.$2, period.$2)));
        expect(find.text('No rankings yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
