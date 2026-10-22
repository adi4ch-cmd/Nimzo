import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';

class TreasureRequest {
  const TreasureRequest(
      {required this.scope,
      required this.total,
      required this.quantity,
      required this.eligibility});
  final String scope, eligibility;
  final int total, quantity;
  bool get valid =>
      {'room', 'world'}.contains(scope) &&
      (scope == 'room'
              ? [10000, 50000, 100000, 200000]
              : [500000, 1000000, 5000000, 10000000])
          .contains(total) &&
      [6, 10, 20, 30].contains(quantity) &&
      {'all', 'fans', 'on_mic'}.contains(eligibility) &&
      !(scope == 'world' && eligibility == 'on_mic');
  Map<String, dynamic> get params => {
        'p_scope': scope,
        'p_total': total,
        'p_quantity': quantity,
        'p_eligibility': eligibility
      };
  factory TreasureRequest.fromParams(Map<String, dynamic> p) {
    if (p['p_scope'] is! String ||
        p['p_total'] is! int ||
        p['p_quantity'] is! int ||
        p['p_eligibility'] is! String) {
      throw const FormatException('Invalid pending treasure');
    }
    final value = TreasureRequest(
        scope: p['p_scope'],
        total: p['p_total'],
        quantity: p['p_quantity'],
        eligibility: p['p_eligibility']);
    if (!value.valid) throw const FormatException('Invalid pending treasure');
    return value;
  }
}

/// A persisted confirmation is a retry instruction, never an entitlement.
class TreasureSendSession {
  TreasureSendSession({required this.userId, required this.roomId});
  final String userId, roomId;
  String get storageKey =>
      'nimzo.pending-treasure.v1.${base64UrlEncode(utf8.encode(jsonEncode([
            userId,
            roomId
          ])))}';
  Map<String, dynamic>? _pending;
  bool _restored = false, _busy = false;
  bool get pending => _pending != null;
  TreasureRequest? get request =>
      _pending == null ? null : TreasureRequest.fromParams(_pending!);
  Future<void> restore() async {
    if (_restored) return;
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw != null) {
      if (raw.length > 2048)
        throw const FormatException('Invalid pending treasure');
      final p = jsonDecode(raw);
      if (p is! Map<String, dynamic> ||
          p['p_room'] != roomId ||
          p['account'] != userId ||
          p['p_key'] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(p['p_key']))
        throw const FormatException('Invalid pending treasure');
      TreasureRequest.fromParams(p);
      _pending = p;
    }
    _restored = true;
  }

  Future<void> _clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(storageKey))
      throw StateError('Treasure confirmation could not be saved');
    _pending = null;
  }

  Future<Map<String, dynamic>> send(
      TreasureRequest request,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)
          submit) async {
    if (_busy) throw StateError('Treasure already submitting');
    _busy = true;
    try {
      await restore();
      if (_pending == null) {
        if (!request.valid) throw ArgumentError('Invalid treasure request');
        _pending = {
          ...request.params,
          'p_room': roomId,
          'account': userId,
          'p_key': List.generate(
              24,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join()
        };
      }
      if (!await (await SharedPreferences.getInstance())
          .setString(storageKey, jsonEncode(_pending)))
        throw StateError('Save confirmation before spending');
      final result = await submit(Map<String, dynamic>.from(_pending!)
        ..remove('account')
        ..['p_expected_sender'] = userId);
      if (result['id'] is! String ||
          (result['id'] as String).isEmpty ||
          !{'funded', 'replayed'}.contains(result['status']))
        throw StateError('Unconfirmed treasure');
      await _clear();
      return result;
    } on PostgrestException catch (e) {
      // Only these errors prove the complete new funding transaction rolled back.
      if (e.code == 'P0001' &&
          {
            'AUTH_REQUIRED',
            'ROOM_MEMBERSHIP_REQUIRED',
            'ROOM_GIFT_DISABLED',
            'INSUFFICIENT_COINS',
            'TREASURE_ACTIVE_LIMIT',
            'TREASURE_INVALID_REQUEST'
          }.contains(e.message)) await _clear();
      rethrow;
    } finally {
      _busy = false;
    }
  }
}

class TreasureBox {
  TreasureBox.fromJson(Map<String, dynamic> p)
      : id = p['id'] as String,
        senderId = p['sender_id'] as String,
        name = p['display_name'] as String? ?? 'Member',
        scope = p['scope'] as String,
        eligibility = p['eligibility'] as String,
        total = (p['total_coins'] as num).toInt(),
        remaining = (p['remaining_coins'] as num).toInt(),
        quantity = (p['quantity'] as num).toInt(),
        claimed = (p['claimed_count'] as num).toInt(),
        claimedCoins = (p['claimed_coins'] as num?)?.toInt(),
        refunded = (p['refunded_coins'] as num).toInt(),
        expiresAt = DateTime.parse(p['expires_at'] as String),
        canClaim = p['can_claim'] == true;
  final String id, senderId, name, scope, eligibility;
  final int total, remaining, quantity, claimed, refunded;
  final int? claimedCoins;
  final DateTime expiresAt;
  final bool canClaim;
}

class TreasureRepository {
  TreasureRepository(this.db);
  final SupabaseClient db;
  Future<List<TreasureBox>> list(String room) async =>
      (await db.rpc('list_room_treasures', params: {'p_room': room}) as List)
          .map((p) => TreasureBox.fromJson(Map<String, dynamic>.from(p)))
          .toList();
  Future<Map<String, dynamic>> create(Map<String, dynamic> params) async =>
      Map<String, dynamic>.from(
          await db.rpc('create_room_treasure', params: params));
  Future<int> claim(String box, String room) async {
    final result = Map<String, dynamic>.from(await db
        .rpc('claim_room_treasure', params: {'p_box': box, 'p_room': room}));
    if (result['box_id'] != box ||
        !{'claimed', 'replayed'}.contains(result['status']) ||
        result['coins'] is! int ||
        result['coins'] <= 0) throw StateError('Claim unconfirmed');
    return result['coins'] as int;
  }

  Stream<List<TreasureBox>> watch(String room) {
    late StreamController<List<TreasureBox>> out;
    RealtimeChannel? channel;
    Timer? poll, debounce;
    var closed = false, busy = false, again = false;
    Future<void> refresh() async {
      if (closed) return;
      if (busy) {
        again = true;
        return;
      }
      busy = true;
      try {
        final boxes = await list(room);
        if (!closed) out.add(boxes);
      } catch (e, s) {
        if (!closed) out.addError(e, s);
      } finally {
        busy = false;
        if (again) {
          again = false;
          unawaited(refresh());
        }
      }
    }

    out = StreamController<List<TreasureBox>>(onListen: () {
      unawaited(refresh());
      poll = Timer.periodic(
          const Duration(seconds: 15), (_) => unawaited(refresh()));
      channel = db
          .channel('treasure:${DateTime.now().microsecondsSinceEpoch}:$room')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'room_treasure_boxes',
              callback: (_) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 200),
                    () => unawaited(refresh()));
              })
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) unawaited(refresh());
      });
    }, onCancel: () {
      closed = true;
      poll?.cancel();
      debounce?.cancel();
      if (channel != null) unawaited(db.removeChannel(channel!));
    });
    return out.stream;
  }
}

final treasureRepositoryProvider = Provider(
    (ref) => TreasureRepository(ref.watch(sessionSupabaseProvider).client));
final roomTreasuresProvider =
    StreamProvider.autoDispose.family<List<TreasureBox>, String>((ref, room) {
  if (ref.watch(currentUserIdProvider) == null)
    return Stream.error(StateError('Sign in required'));
  return ref.watch(treasureRepositoryProvider).watch(room);
});
