import 'private_animal_gifts.dart';
import '../../core/providers/supabase_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import 'gift_error.dart';

class Gift {
  final String id, name, category;
  final int price;
  final String? assetPath;
  const Gift(this.id, this.name, this.category, this.price, this.assetPath);
}

class GiftRepository {
  // Historical paid gift receipts are private audit records.
  // Do not query the retired public gift_events history from a client.
  Stream<List<Map<String, dynamic>>> watchRoomGiftEvents(String roomId) =>
      Stream.value(const <Map<String, dynamic>>[]);

  /// Read-only, RLS-scoped animation events created by the settlement trigger.
  /// Subscribe only while a room is active; do not treat these as payment proof
  /// for any client-side wallet updates.
  Stream<List<Map<String, dynamic>>> watchVerifiedAnimations({
    required String roomId,
    required String countryCode,
  }) {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      return _db
          .from('gift_animation_events')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(20)
          .map(
            (rows) => rows
                .where((row) => row['scope'] == 'room')
                .map((row) => Map<String, dynamic>.from(row))
                .toList(),
          );
    }
    // RLS restricts country broadcasts to the signed-in user's country.
    // Room events are filtered locally after the RLS-scoped stream.
    return _db
        .from('gift_animation_events')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map(
          (rows) => rows
              .where(
                (row) =>
                    (row['scope'] == 'room' && row['room_id'] == roomId) ||
                    (row['scope'] == 'country' &&
                        row['country_code'] == normalized),
              )
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
        );
  }

  /// Only admin-approved HTTPS video media may be played.
  Future<String?> approvedAnimationUrl(String giftId) async {
    if (privateAnimalVapGiftIds.contains(giftId)) {
      return privateMediaUrl(giftId, kind: 'animation');
    }
    final rows = await _db
        .from('gift_animation_media')
        .select('video_url')
        .eq('gift_id', giftId)
        .eq('approved', true)
        .limit(1);
    if (rows.isEmpty) return null;
    final url = rows.first['video_url'] as String?;
    final uri = Uri.tryParse(url ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? url
        : null;
  }

  /// Checks private media availability before a debit without issuing a URL.
  Future<bool> privateMediaReady(String giftId) async {
    if (!privateAnimalVapGiftIds.contains(giftId)) return false;
    final response = await _db.functions.invoke(
      'gift-media', body: {'gift_id': giftId, 'kind': 'ready'},
    );
    final body = response.data;
    return body is Map && body['ready'] == true;
  }

  Future<String?> privateMediaUrl(String giftId, {required String kind}) async {
    if (!privateAnimalVapGiftIds.contains(giftId)) return null;
    final response = await _db.functions.invoke(
      'gift-media',
      body: {'gift_id': giftId, 'kind': kind},
    );
    final data = response.data;
    final url = data is Map ? data['url'] as String? : null;
    final uri = Uri.tryParse(url ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? url
        : null;
  }

  final SupabaseClient _db;
  GiftRepository(this._db);

  /// Names always come from authenticated, RLS-filtered public profiles.
  /// Event metadata is server-sourced and never grants payment authority.
  Future<Map<String, String>> participantNamesForVerifiedEvent(
    Map<String, dynamic> event,
  ) async {
    final ids =
        <String>{
              if (event['sender_id'] is String) event['sender_id'] as String,
              if (event['receiver_id'] is String)
                event['receiver_id'] as String,
            }
            .where(
              (id) => RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              ).hasMatch(id),
            )
            .toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _db
          .from('profiles')
          .select('id,nimzo_id,display_name,username')
          .inFilter('id', ids)
          .limit(2);
      final names = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || !ids.contains(id)) continue;
        final display = (row['display_name'] as String?)?.trim();
        final username = (row['username'] as String?)?.trim();
        final number = row['nimzo_id'];
        final name = display != null && display.isNotEmpty
            ? display
            : username != null && username.isNotEmpty
            ? username
            : number is num
            ? 'ID ${number.toString()}'
            : '';
        if (name.isNotEmpty) names[id] = name;
      }
      return names;
    } catch (_) {
      // Offline or denied profile reads never block a settled effect.
      return const {};
    }
  }

  Future<List<Gift>> catalog() async {
    try {
      final r = await _db
          .from('gifts')
          .select()
          .eq('active', true)
          .order('coin_price');
      return r
          .map(
            (j) => Gift(
              j['id'],
              j['name'],
              j['category'],
              (j['coin_price'] as num).toInt(),
              j['asset_path'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> sendProfile({
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {
    _validateGiftRequest(receiverId, giftId, qty, key);
    try {
      await _db.rpc(
        'send_profile_gift',
        params: {
          'p_receiver': receiverId,
          'p_gift': giftId,
          'p_qty': qty,
          'p_key': key,
        },
      );
    } catch (e) {
      throw mapGiftError(e);
    }
  }

  /// Price, balance and the 45/5 split are decided by Postgres `send_gift`.
  /// The idempotency key makes retries safe.
  Future<void> send({
    required String roomId,
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {
    if (roomId.trim().isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Room is required.');
    }
    _validateGiftRequest(receiverId, giftId, qty, key);
    try {
      await _db.rpc(
        'send_gift',
        params: {
          'p_room': roomId,
          'p_receiver': receiverId,
          'p_gift': giftId,
          'p_qty': qty,
          'p_key': key,
        },
      );
    } catch (e) {
      throw mapGiftError(e);
    }
  }

  static void _validateGiftRequest(
    String receiverId,
    String giftId,
    int qty,
    String key,
  ) {
    if (receiverId.trim().isEmpty) {
      throw ArgumentError.value(
        receiverId,
        'receiverId',
        'Recipient is required.',
      );
    }
    if (giftId.trim().isEmpty) {
      throw ArgumentError.value(giftId, 'giftId', 'Gift is required.');
    }
    if (qty <= 0) {
      throw RangeError.value(qty, 'qty', 'Quantity must be positive.');
    }
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Idempotency key is required.');
    }
  }
}

final giftRepositoryProvider = Provider(
  (ref) => GiftRepository(ref.watch(sessionSupabaseProvider).client),
);
final giftCatalogProvider = FutureProvider(
  (ref) => ref.watch(giftRepositoryProvider).catalog(),
);
final roomGiftEventProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, roomId) =>
          ref.watch(giftRepositoryProvider).watchRoomGiftEvents(roomId),
    );

final verifiedGiftAnimationProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String roomId, String countryCode})>(
      (ref, args) => ref
          .watch(giftRepositoryProvider)
          .watchVerifiedAnimations(
            roomId: args.roomId,
            countryCode: args.countryCode,
          ),
    );

final privateGiftThumbnailProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, giftId) => ref
          .watch(giftRepositoryProvider)
          .privateMediaUrl(giftId, kind: 'thumbnail'),
    );
