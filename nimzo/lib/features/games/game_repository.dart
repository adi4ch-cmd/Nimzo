import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_catalog.dart';

class GameRepository {
  final SupabaseClient db;
  GameRepository(this.db);
  Future<Map<String, dynamic>> play({
    required String? roomId,
    required String game,
    required int bet,
    required String key,
  }) async {
    if (roomId == null ||
        roomId.trim().isEmpty ||
        !NimzoRoomGames.canPlay(game) ||
        bet < 1 ||
        bet > 500000 ||
        key.trim().isEmpty)
      throw StateError('Invalid game request');
    return Map<String, dynamic>.from(
      await db.rpc(
        'play_game',
        params: {
          'p_room': roomId,
          'p_game_slug': game,
          'p_bet_amount': bet,
          'p_client_key': key,
        },
      ),
    );
  }
}
