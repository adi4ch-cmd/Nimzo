import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/games/game_repository.dart';

void main() {
  test(
    'invalid coin game requests are rejected before any network call',
    () async {
      final db = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async {
          fail('Invalid game request reached Supabase');
        }),
      );
      addTearDown(db.dispose);
      final repo = GameRepository(db);

      Future<void> rejected({
        String? roomId = 'room',
        String game = 'fruit_wheel',
        int bet = 1000,
        String key = 'unique-round',
      }) async {
        await expectLater(
          repo.play(roomId: roomId, game: game, bet: bet, key: key),
          throwsStateError,
        );
      }

      await rejected(roomId: null);
      await rejected(roomId: ' ');
      await rejected(game: 'unknown');
      await rejected(bet: 0);
      await rejected(bet: -1);
      await rejected(bet: 500001);
      await rejected(key: '');
      await rejected(key: '  ');
    },
  );
}
