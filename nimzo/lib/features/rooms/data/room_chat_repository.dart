import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/providers/supabase_provider.dart';

class RoomMessage {
  final String id, userId, body;
  final DateTime at;
  const RoomMessage(this.id, this.userId, this.body, this.at);
}

class RoomChatRepository {
  final SupabaseClient _db;
  RoomChatRepository(this._db);

  Stream<List<RoomMessage>> watch(String roomId) => _db
      .from('room_messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(50)
      .map(
        (r) => r
            .map(
              (j) => RoomMessage(
                j['id'],
                j['user_id'],
                j['body'],
                DateTime.parse(j['created_at']),
              ),
            )
            .toList(),
      );

  /// Chat permission, mute and membership are checked in Postgres.
  Future<void> send(String roomId, String body) async {
    try {
      await _db.rpc(
        'send_room_chat',
        params: {'p_room': roomId, 'p_body': body},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> clear(String roomId) async {
    try {
      await _db.rpc('clear_room_chat', params: {'p_room': roomId});
    } catch (e) {
      throw mapError(e);
    }
  }

  Stream<int> watchOnline(String roomId) => _db
      .from('room_members')
      .stream(primaryKey: ['room_id', 'user_id'])
      .eq('room_id', roomId)
      .map((r) => r.length);

  /// Room-wide gift events, drives GiftAnimationService.
  Stream<List<Map<String, dynamic>>> watchGifts(String roomId) => _db
      .from('gift_events')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(1);
}

final roomChatRepositoryProvider = Provider(
  (ref) => RoomChatRepository(ref.watch(sessionSupabaseProvider).client),
);
final roomChatProvider = StreamProvider.autoDispose
    .family<List<RoomMessage>, String>(
      (ref, id) => ref.watch(roomChatRepositoryProvider).watch(id),
    );
final onlineCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, id) => ref.watch(roomChatRepositoryProvider).watchOnline(id),
);
final roomGiftEventProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(roomChatRepositoryProvider).watchGifts(id),
    );
