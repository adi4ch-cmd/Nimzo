import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
        (key.trim().isEmpty || key.length > 200))
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

/// Keeps uncertain network retries bound to the original request. A new round
/// is possible only after the server confirms settlement.
class GameRequestScope {
  const GameRequestScope(
      {required this.userId, required this.roomId, required this.game});
  final String userId, roomId, game;
  String get storageKey =>
      'nimzo.pending-game.v1.${base64UrlEncode(utf8.encode(jsonEncode([
            userId,
            roomId,
            game
          ])))}';
}

class GameRetrySession {
  GameRetrySession({this.scope});
  final GameRequestScope? scope;
  ({int bet, String key})? _request;
  bool get pending => _request != null;
  int? get pendingBet => _request?.bet;
  bool _busy = false;
  bool _restored = false;

  Future<void> restore() async {
    if (_restored) return;
    if (scope != null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(scope!.storageKey);
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is! Map ||
            data['bet'] is! int ||
            data['bet'] < 1 ||
            data['bet'] > 500000 ||
            data['key'] is! String ||
            !RegExp(r'^[a-f0-9]{48}$').hasMatch(data['key'])) {
          throw const FormatException(
              'Pending round cannot be safely recovered');
        }
        _request = (bet: data['bet'] as int, key: data['key'] as String);
      }
    }
    _restored = true;
  }

  Future<void> _save() async {
    if (scope == null) return;
    final prefs = await SharedPreferences.getInstance();
    final request = _request!;
    if (!await prefs.setString(scope!.storageKey,
        jsonEncode({'bet': request.bet, 'key': request.key}))) {
      throw StateError('Round must be saved before spending coins');
    }
  }

  Future<void> _clear() async {
    if (scope != null) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(scope!.storageKey))
        throw StateError('Round receipt could not be saved');
    }
    _request = null;
  }

  Future<Map<String, dynamic>> play(
    int bet,
    Future<Map<String, dynamic>> Function(int bet, String key) submit,
  ) async {
    if (_busy) throw StateError('A round is already in progress');
    _busy = true;
    try {
      await restore();
      _request ??= (
        bet: bet,
        key: List.generate(
            24,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join()
      );
      final request = _request!;
      await _save();
      final result = await submit(request.bet, request.key);
      if (!{'won', 'lost'}.contains(result['status']) ||
          result['payout'] is! num ||
          result['bet_id'] is! String) {
        throw StateError('Settlement could not be verified');
      }
      await _clear();
      return result;
    } on PostgrestException catch (error) {
      // A database exception rolls the complete RPC transaction back. Keep
      // unknown errors and payload mismatches pending for explicit recovery.
      if (error.code == 'P0001' &&
          {
            'AUTH_REQUIRED',
            'ACCOUNT_RESTRICTED',
            'ROOM_MEMBERSHIP_REQUIRED',
            'ROOM_GAME_DISABLED',
            'INVALID_BET',
            'BET_LIMIT_EXCEEDED',
            'GAME_NOT_FOUND',
            'WALLET_NOT_FOUND',
            'INSUFFICIENT_COINS',
            'UNSUPPORTED_GAME',
          }.contains(error.message)) {
        await _clear();
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }
}
