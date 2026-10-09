import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/providers/supabase_provider.dart';

class RoomSettings {
  final String name, theme;
  final String? avatarPath;
  final bool isPrivate, mic, chat, guest, gift, music, game, visitor;
  const RoomSettings({
    required this.name,
    required this.theme,
    this.avatarPath,
    required this.isPrivate,
    this.mic = true,
    this.chat = true,
    this.guest = true,
    this.gift = true,
    this.music = true,
    this.game = true,
    this.visitor = true,
  });
  factory RoomSettings.fromJson(Map<String, dynamic> j) => RoomSettings(
        name: j['name'],
        theme: j['theme'],
        avatarPath: j['avatar_path'] as String?,
        isPrivate: j['is_private'],
        mic: j['perm_mic'] ?? true,
        chat: j['perm_chat'] ?? true,
        guest: j['perm_guest'] ?? true,
        gift: j['perm_gift'] ?? true,
        music: j['perm_music'] ?? true,
        game: j['perm_game'] ?? true,
        visitor: j['perm_visitor'] ?? true,
      );
}

class RoomSettingsRepository {
  final SupabaseClient _db;
  RoomSettingsRepository(this._db);

  Future<RoomSettings> get(String id) async => RoomSettings.fromJson(
        await _db
            .from('rooms')
            .select(
              'id,room_no,owner_id,name,country,theme,is_private,status,created_at,rules,mic_permission,chat_permission,guest_permission,gift_permission,music_permission,game_permission,visitor_permission,perm_mic,perm_chat,perm_guest,perm_gift,perm_music,perm_game,perm_visitor,last_active,avatar_path,lifetime_gift_coins',
            )
            .eq('id', id)
            .single(),
      );

  /// Owner-only, validated in Postgres. Password is hashed server-side.
  Future<void> save(String id, RoomSettings s, {String? password}) async {
    try {
      await _db.rpc(
        'save_room_settings',
        params: {
          'p_room': id,
          'p_name': s.name,
          'p_theme': s.theme,
          'p_private': s.isPrivate,
          'p_password': password,
          'p_mic': s.mic,
          'p_chat': s.chat,
          'p_guest': s.guest,
          'p_gift': s.gift,
          'p_music': s.music,
          'p_game': s.game,
          'p_visitor': s.visitor,
          'p_avatar_path': s.avatarPath,
        },
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> members(String roomId) async =>
      List<Map<String, dynamic>>.from(
        await _db.rpc('room_member_list', params: {'p_room': roomId}),
      );
  Future<void> setModerator(String roomId, String userId, bool on) async {
    try {
      await _db.rpc(
        'set_moderator',
        params: {'p_room': roomId, 'p_user': userId, 'p_on': on},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> report(String roomId, String reason) async {
    try {
      await _db.from('reports').insert({
        'reporter_id': _db.auth.currentUser!.id,
        'target_type': 'room',
        'target_id': roomId,
        'reason': reason,
      });
    } catch (e) {
      throw mapError(e);
    }
  }
}

final roomSettingsRepositoryProvider = Provider(
  (ref) => RoomSettingsRepository(ref.watch(sessionSupabaseProvider).client),
);
final roomSettingsProvider = FutureProvider.family<RoomSettings, String>(
  (ref, id) => ref.watch(roomSettingsRepositoryProvider).get(id),
);
final roomMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, id) => ref.watch(roomSettingsRepositoryProvider).members(id),
);
