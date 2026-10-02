import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/providers/supabase_provider.dart';

class ChatMessage {
  final String id, userId, body;
  final DateTime createdAt;
  const ChatMessage(this.id, this.userId, this.body, this.createdAt);
}

class RoomExtrasRepository {
  final SupabaseClient _db;
  RoomExtrasRepository(this._db);

  Future<String> create(String name, String? country, String? password) async {
    try { return await _db.rpc('create_room', params: {'p_name': name, 'p_country': country, 'p_password': password}) as String; }
    catch (e) { throw mapError(e); }
  }
  Future<void> updateSettings(String roomId, Map<String, dynamic> s) async {
    try { await _db.rpc('update_room_settings', params: {'p_room': roomId, 'p_settings': s}); } catch (e) { throw mapError(e); }
  }
  Future<void> setPassword(String roomId, String? pw) async {
    try { await _db.rpc('set_room_password', params: {'p_room': roomId, 'p_password': pw}); } catch (e) { throw mapError(e); }
  }
  Future<void> setModerator(String roomId, String userId, bool on) async {
    try { await _db.rpc('set_moderator', params: {'p_room': roomId, 'p_user': userId, 'p_on': on}); } catch (e) { throw mapError(e); }
  }
  Future<void> sendChat(String roomId, String body) async {
    try { await _db.rpc('send_room_message', params: {'p_room': roomId, 'p_body': body}); } catch (e) { throw mapError(e); }
  }
  Stream<List<ChatMessage>> watchChat(String roomId) => _db.from('room_messages').stream(primaryKey: ['id'])
      .eq('room_id', roomId).order('created_at')
      .map((r) => r.map((j) => ChatMessage(j['id'], j['user_id'], j['body'], DateTime.parse(j['created_at']))).toList());
  Future<List<Map<String, dynamic>>> members(String roomId) async =>
      await _db.from('room_members').select('user_id,role,profiles(display_name,nimzo_id)').eq('room_id', roomId);
  Future<void> reportRoom(String roomId, String reason) async {
    try { await _db.from('reports').insert({'reporter_id': _db.auth.currentUser!.id, 'target_type': 'room', 'target_id': roomId, 'reason': reason}); }
    catch (e) { throw mapError(e); }
  }
}

final roomExtrasProvider = Provider((ref) => RoomExtrasRepository(ref.watch(supabaseProvider)));
final roomChatProvider = StreamProvider.family<List<ChatMessage>, String>((ref, id) => ref.watch(roomExtrasProvider).watchChat(id));
final roomMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) => ref.watch(roomExtrasProvider).members(id));
