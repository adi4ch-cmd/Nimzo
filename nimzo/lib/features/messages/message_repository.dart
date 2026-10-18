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

  String _conversationKey(String other) {
    final ids = [_me.toLowerCase(), other.toLowerCase()]..sort();
    return ids.join(':');
  }

  Stream<List<Message>> watch(String other) async* {
    yield await recent(other);
    // Re-fetch after initial subscribe and reconnect to cover messages received
    // while the subscription was unavailable. All REST reads stay pair-scoped.
    yield* accountTableActivity(_db, 'messages', ['sender_id', 'receiver_id'],
            emitInitial: true)
        .asyncMap((_) => recent(other));
  }

  Future<List<Message>> recent(String other) async {
    final rows = await _db
        .from('messages')
        .select()
        .eq('conversation_key', _conversationKey(other))
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50);
    return mergeMessageHistory(const [], rows.map(Message.fromJson));
  }

  Future<List<Message>> older(String other, {required Message before}) async {
    final timestamp = before.createdAt.toUtc().toIso8601String();
    final rows = await _db
        .from('messages')
        .select()
        .eq('conversation_key', _conversationKey(other))
        .or('created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${before.id})')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50);
    return mergeMessageHistory(const [], rows.map(Message.fromJson));
  }

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

/// Live rows win over cached history, including updated read receipts.
List<Message> mergeMessageHistory(
    Iterable<Message> history, Iterable<Message> live) {
  final unique = <String, Message>{for (final m in history) m.id: m};
  for (final message in live) {
    unique[message.id] = message;
  }
  return unique.values.toList()
    ..sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
}

/// Retain rows that leave a sliding live window. A disjoint reconnect page
/// restarts pagination so an unseen middle range never becomes unreachable.
({List<Message> rows, bool reset}) reconcileMessageWindow(
    List<Message> cached, List<Message> recent,
    {required Set<String> previousPageIds}) {
  final ordered = mergeMessageHistory(const [], recent);
  if (ordered.isEmpty)
    return (rows: <Message>[], reset: previousPageIds.isNotEmpty);
  final reset = previousPageIds.isNotEmpty &&
      !ordered.any((m) => previousPageIds.contains(m.id));
  if (reset) return (rows: ordered, reset: true);
  final first = ordered.first;
  final retained = cached.where((m) {
    final time = m.createdAt.compareTo(first.createdAt);
    return time < 0 || (time == 0 && m.id.compareTo(first.id) < 0);
  });
  return (rows: mergeMessageHistory(retained, ordered), reset: false);
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
