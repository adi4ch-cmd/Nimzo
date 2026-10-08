import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/recharge/recharge_repository.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/games/game_repository.dart';

SupabaseClient client(http.Response Function(http.Request) reply) =>
    SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((r) async {
        final response = reply(r);
        return http.Response(
          response.body,
          response.statusCode,
          request: r,
          headers: {...response.headers, 'content-type': 'application/json'},
        );
      }),
    );
void main() {
  test(
    'verification refuses HTTP success without explicit settlement',
    () async {
      final repo = RechargeRepository(
        client((_) => http.Response('{"error":"settlement failed"}', 200)),
      );
      await expectLater(
        repo.verify(store: 'google', productId: 'coins', receipt: 'token'),
        throwsA(isA<StateError>()),
      );
    },
  );
  test('verification rejects bare success without matching settlement',
      () async {
    await expectLater(
        RechargeRepository(client((_) => http.Response('{"ok":true}', 200)))
            .verify(store: 'google', productId: 'coins', receipt: 'token'),
        throwsStateError);
  });
  test('verification accepts confirmed settlement and normalizes store alias',
      () async {
    await RechargeRepository(client((_) => http.Response(
        '{"ok":true,"status":"credited","store":"google_play","product_id":"coins","transaction_id":"token","coins":500000,"environment":"production"}',
        200))).verify(store: 'google', productId: 'coins', receipt: 'token');
  });
  test('roomless games refuse before sending a request', () async {
    var calls = 0;
    final repo = GameRepository(
      client((_) {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      repo.play(roomId: null, game: 'fruit_wheel', bet: 1000, key: 'same-key'),
      throwsStateError,
    );
    expect(calls, 0);
  });
  test('game forwards room and stable key and keeps server payout', () async {
    final repo = GameRepository(
      client((r) {
        final body = jsonDecode(r.body) as Map;
        expect(body['p_room'], 'room-id');
        expect(body['p_client_key'], 'same-key');
        return http.Response(
          '{"payout":0,"result":{"symbol":"lemon","segment":2}}',
          200,
        );
      }),
    );
    final result = await repo.play(
      roomId: 'room-id',
      game: 'fruit_wheel',
      bet: 1000,
      key: 'same-key',
    );
    expect(result['payout'], 0);
    expect(result['result']['symbol'], 'lemon');
  });
  test('moment detail shows real like and comment counts', () async {
    final db = client((r) {
      if (r.url.path.endsWith('/moments'))
        return http.Response(
          jsonEncode({
            'id': 'm',
            'author_id': 'a',
            'created_at': '2026-10-06T00:00:00Z',
          }),
          200,
        );
      if (r.url.path.endsWith('/moment_likes'))
        return http.Response('', 200, headers: {'content-range': '0-1/2'});
      if (r.url.path.endsWith('/moment_comments'))
        return http.Response('', 200, headers: {'content-range': '0-0/1'});
      return http.Response('[]', 200);
    });
    final moment = await MomentRepository(db).get('m');
    expect(moment.likes, 2);
    expect(moment.comments, 1);
    expect(moment.liked, false);
  });
}
