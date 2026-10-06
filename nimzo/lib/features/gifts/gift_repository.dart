import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/error_handler.dart';

class Gift {
  final String id, name, category;
  final int price;
  final String? assetPath;
  const Gift(this.id, this.name, this.category, this.price, this.assetPath);
}

class GiftRepository {
  Stream<List<Map<String, dynamic>>> watchRoomGiftEvents(String roomId) => _db
      .from('gift_events')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(20)
      .map(
          (rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
  final SupabaseClient _db;
  GiftRepository(this._db);

  Future<List<Gift>> catalog() async {
    try {
      final r = await _db
          .from('gifts')
          .select()
          .eq('active', true)
          .order('coin_price');
      return r
          .map((j) => Gift(j['id'], j['name'], j['category'],
              (j['coin_price'] as num).toInt(), j['asset_path'] as String?))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> sendProfile(
      {required String receiverId,
      required String giftId,
      required int qty,
      required String key}) async {
    try {
      await _db.rpc('send_profile_gift', params: {
        'p_receiver': receiverId,
        'p_gift': giftId,
        'p_qty': qty,
        'p_key': key,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Price, balance and the 45/5 split are decided by Postgres `send_gift`.
  /// The idempotency key makes retries safe.
  Future<void> send(
      {required String roomId,
      required String receiverId,
      required String giftId,
      required int qty,
      required String key}) async {
    try {
      await _db.rpc('send_gift', params: {
        'p_room': roomId,
        'p_receiver': receiverId,
        'p_gift': giftId,
        'p_qty': qty,
        'p_key': key
      });
    } catch (e) {
      throw mapError(e);
    }
  }
}

final giftRepositoryProvider =
    Provider((ref) => GiftRepository(Supabase.instance.client));
final giftCatalogProvider =
    FutureProvider((ref) => ref.watch(giftRepositoryProvider).catalog());
final roomGiftEventProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, roomId) =>
      ref.watch(giftRepositoryProvider).watchRoomGiftEvents(roomId),
);
