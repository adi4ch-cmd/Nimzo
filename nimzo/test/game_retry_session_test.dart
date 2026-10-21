import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/games/game_repository.dart';

void main() {
  test('definitive insufficient balance allows a corrected wager', () async {
    final session = GameRetrySession();
    await expectLater(
        session.play(500, (_, __) async {
          throw const PostgrestException(
              message: 'INSUFFICIENT_COINS', code: 'P0001');
        }),
        throwsA(isA<PostgrestException>()));
    expect(session.pending, isFalse);
    var requested = 0;
    await session.play(100, (bet, _) async {
      requested = bet;
      return {'status': 'lost', 'payout': 0, 'bet_id': 'bet'};
    });
    expect(requested, 100);
  });

  test('failed settlement preserves the original wager and key until confirmed',
      () async {
    final calls = <({int bet, String key})>[];
    final session = GameRetrySession();
    Future<Map<String, dynamic>> submit(int bet, String key) async {
      calls.add((bet: bet, key: key));
      if (calls.length == 1) throw StateError('Connection lost');
      return {'status': 'lost', 'payout': 0, 'bet_id': 'bet'};
    }

    await expectLater(session.play(100, submit), throwsStateError);
    expect(session.pending, isTrue);
    await session.play(500, submit);
    expect(calls[0], calls[1]);
    expect(calls[1].bet, 100);
    expect(session.pending, isFalse);
    await session.play(500, submit);
    expect(calls[2].bet, 500);
    expect(calls[2].key, isNot(calls[1].key));
  });
}
