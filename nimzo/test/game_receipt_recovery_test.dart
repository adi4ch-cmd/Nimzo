import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/games/game_repository.dart';

void main() {
  test('settled receipt is recovered without submitting another game',
      () async {
    final paths = <String>[];
    final db = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      expect(request.url.path, endsWith('/rpc/my_game_receipt'));
      expect(jsonDecode(request.body), {
        'p_room': 'room',
        'p_game': 'fruit_party',
        'p_bet': 100,
        'p_key': 'original-key'
      });
      return http.Response(
          '{"bet_id":"settled-bet","status":"won","payout":200,"duplicate":true,"result":{"grid":[]}}',
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(db.dispose);
    final result = await GameRepository(db, expectedUserId: 'account-a').play(
        roomId: 'room', game: 'fruit_party', bet: 100, key: 'original-key');
    expect(result['bet_id'], 'settled-bet');
    expect(paths, hasLength(1));
  });
  test('receipt lookup failure never submits a new wager', () async {
    final paths = <String>[];
    final db = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('{"message":"unavailable"}', 503,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(db.dispose);
    await expectLater(
        GameRepository(db, expectedUserId: 'account-a').play(
            roomId: 'room', game: 'fruit_party', bet: 100, key: 'original-key'),
        throwsA(anything));
    expect(paths, everyElement(endsWith('/rpc/my_game_receipt')));
  });
  test('new wager is bound to the confirming account after receipt await',
      () async {
    final paths = <String>[];
    final db = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (paths.length == 1)
        return http.Response('{"status":"missing"}', 200,
            request: request, headers: {'content-type': 'application/json'});
      expect(request.url.path, endsWith('/rpc/play_game_checked'));
      expect(jsonDecode(request.body)['p_expected_user'], 'account-a');
      return http.Response('{"bet_id":"bet","status":"lost","payout":0}', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(db.dispose);
    await GameRepository(db, expectedUserId: 'account-a').play(
        roomId: 'room', game: 'fruit_party', bet: 100, key: 'original-key');
    expect(paths, hasLength(2));
  });
}
