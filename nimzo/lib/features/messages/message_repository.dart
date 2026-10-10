import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import '../../core/services/account_table_activity.dart';
import '../../core/providers/supabase_provider.dart';

class Message {
  final String id, senderId, receiverId, kind;
  final String? body;
  final bool read;
  final DateTime createdAt;
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.kind,
    this.body,
    required this.read,
    required this.createdAt,
  });
  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        senderId: j['sender_id'],
        receiverId: j['receiver_id'],
        kind: j['kind'] ?? 'text',
        body: j['body'],
        read: j['read_at'] != null,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class MessageRepository {
  final SupabaseClient _db;
  MessageRepository(this._db);
  String get _me => _db.auth.currentUser!.id;

  Stream<int> changes() =>
      accountTableActivity(_db, 'messages', ['sender_id', 'receiver_id']);

  Future<List<Map<String, dynamic>>> conversations() async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db.rpc('conversation_list'),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Stream<List<Message>> watch(String other) =>
      _db.from('messages').stream(primaryKey: ['id']).order('created_at').map(
            (rows) => rows
                .where(
                  (r) =>
                      (r['sender_id'] == _me && r['receiver_id'] == other) ||
                      (r['sender_id'] == other && r['receiver_id'] == _me),
                )
                .map(Message.fromJson)
                .toList(),
          );

  /// kind: text | emoji | gift | room_invite. Blocked-user checks happen in RLS/RPC.
  Future<void> send(String to, String body, {String kind = 'text'}) async {
    try {
      await _db.rpc(
        'send_message',
        params: {'p_to': to, 'p_body': body, 'p_kind': kind},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> markRead(String other) =>
      _db.rpc('mark_read', params: {'p_from': other});

  /// Typing indicator over Realtime broadcast (ephemeral, no DB writes).
  RealtimeChannel typingChannel(String other) {
    final ids = [_me, other]..sort();
    return _db.channel('typing:${ids.join(':')}');
  }
}

final messageRepositoryProvider = Provider(
  (ref) => MessageRepository(ref.watch(sessionSupabaseProvider).client),
);
final conversationActivityProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(messageRepositoryProvider).changes(),
);
final conversationsProvider = FutureProvider((ref) {
  ref.watch(conversationActivityProvider);
  return ref.watch(messageRepositoryProvider).conversations();
});
final chatProvider = StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, other) => ref.watch(messageRepositoryProvider).watch(other),
);
