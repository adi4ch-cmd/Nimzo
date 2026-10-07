import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import 'game_catalog.dart';

class GameRepository {
  final SupabaseClient _db;
  GameRepository(this._db);
  Future<Map<String, dynamic>> play({
    required String? roomId,
    required String game,
    required int bet,
    required String key,
  }) async {
    if (roomId == null || roomId.trim().isEmpty)
      throw StateError('Open a room before playing.');
    if (!NimzoRoomGames.canPlay(game))
      throw StateError('Game unavailable');
    if (bet <= 0 || bet > 500000)
      throw StateError('Bet must be between 1 and 500,000 coins.');
    if (key.trim().isEmpty)
      throw StateError('A unique round request key is required.');
    final response = await _db.rpc(
      'play_game',
      params: {
        'p_room': roomId,
        'p_game_slug': game,
        'p_bet_amount': bet,
        'p_bet_type': 'spin',
        'p_selection': null,
        'p_client_key': key,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> wheelSegments() async {
    final config = await _db.rpc(
      'game_config',
      params: {'p_slug': 'fruit_wheel'},
    );
    return List<Map<String, dynamic>>.from(
      (config as Map)['wheel_segments'] as List,
    );
  }
}

final gameRepositoryProvider = Provider(
  (ref) => GameRepository(ref.watch(supabaseProvider)),
);
final wheelSegmentsProvider = FutureProvider(
  (ref) => ref.watch(gameRepositoryProvider).wheelSegments(),
);
