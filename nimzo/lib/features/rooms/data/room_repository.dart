import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../domain/room.dart';
import '../../profile/profile.dart';

class RoomRepository {
  final SupabaseClient _db;
  RoomRepository(this._db);

  Future<List<Room>> popular({String? country}) async {
    try {
      var q = _db.from('rooms_ranked').select().eq('status', 'open');
      if (country != null) q = q.eq('country', country);
      final rows = await q.order('member_count', ascending: false).limit(50);
      return rows.map(Room.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Room>> newRooms() =>
      _list(since: DateTime.now().subtract(const Duration(days: 15)));

  Future<List<Room>> _list({String? country, DateTime? since}) async {
    try {
      var q = _db
          .from('rooms')
          .select(
            'id,room_no,owner_id,name,country,theme,is_private,status,created_at,rules,mic_permission,chat_permission,guest_permission,gift_permission,music_permission,game_permission,visitor_permission,perm_mic,perm_chat,perm_guest,perm_gift,perm_music,perm_game,perm_visitor,last_active,avatar_path,lifetime_gift_coins',
          )
          .eq('status', 'open');
      if (country != null) q = q.eq('country', country);
      if (since != null) q = q.gte('created_at', since.toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(50);
      return rows.map(Room.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Map<String, List<Room>>> myRooms() async {
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('my_rooms'));
      List<Room> l(String k) => (r[k] as List? ?? [])
          .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return {'recent': l('recent'), 'followed': l('followed')};
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> followRoom(String id, bool on) async {
    try {
      await _db.rpc('follow_room', params: {'p_room': id, 'p_on': on});
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Room> get(String id) async {
    try {
      return Room.fromJson(
        await _db
            .from('rooms')
            .select(
              'id,room_no,owner_id,name,country,theme,is_private,status,created_at,rules,mic_permission,chat_permission,guest_permission,gift_permission,music_permission,game_permission,visitor_permission,perm_mic,perm_chat,perm_guest,perm_gift,perm_music,perm_game,perm_visitor,last_active,avatar_path,lifetime_gift_coins',
            )
            .eq('id', id)
            .single(),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Return the permanent room owned by the signed-in user, if any.
  /// Closed rooms are included: one user may own only one room.
  Future<String?> ownedRoomId() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in again');
    final room =
        await _db.from('rooms').select('id').eq('owner_id', uid).maybeSingle();
    return room?['id']?.toString();
  }

  /// Room creation is performed by the SECURITY DEFINER RPC so the owner,
  /// ten mic seats and membership are initialized atomically server-side.
  Future<String> create(
    String name, {
    String? country,
    String? password,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw StateError('Room name must contain 1 to 40 characters.');
    }
    // Reuse the existing permanent room; do not create a second room.
    final existing = await ownedRoomId();
    if (existing != null) return existing;
    try {
      final id = await _db.rpc(
        'create_room',
        params: {
          'p_name': trimmed,
          'p_country': country,
          'p_password': password,
        },
      );
      return id.toString();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> join(String roomId, {String? password}) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in again');
    final previous = await _db
        .from('room_members')
        .select('room_id')
        .eq('user_id', uid)
        .maybeSingle();
    if (previous != null && previous['room_id'] != roomId)
      await leave(previous['room_id'] as String);
    await _rpc('join_room', {'p_room': roomId, 'p_password': password});
  }

  Future<void> leave(String roomId) => _rpc('leave_room', {'p_room': roomId});
  Future<void> takeSeat(String roomId, int seat) =>
      _rpc('take_seat', {'p_room': roomId, 'p_seat': seat});
  Future<void> leaveSeat(String roomId) =>
      _rpc('leave_seat', {'p_room': roomId});
  Future<void> modMuteSeat(String roomId, int seat, bool muted) => _rpc(
        'mod_mute_seat',
        {'p_room': roomId, 'p_seat': seat, 'p_muted': muted},
      );
  Future<bool> canModerate(String roomId) async {
    try {
      return await _db.rpc('get_room_moderation', params: {'p_room': roomId}) ==
          true;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> moderateMember(
    String roomId,
    String userId, {
    required bool ban,
  }) =>
      _rpc('moderate_room_member', {
        'p_room': roomId,
        'p_user': userId,
        'p_ban': ban,
      });

  Future<void> kick(String roomId, String userId) =>
      _rpc('kick_member', {'p_room': roomId, 'p_user': userId});

  Future<void> _rpc(String fn, Map<String, dynamic> args) async {
    try {
      await _db.rpc(fn, params: args);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Profile>> profilesForUsers(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _db.from('profiles').select().inFilter('id', ids);
      return rows
          .map((r) => Profile.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  /// All currently joined room identities, including listeners off mic.
  /// A server leave/delete removes the ID from this Realtime collection.
  Stream<List<String>> watchMembers(String roomId) => _db
      .from('room_members')
      .stream(primaryKey: ['room_id', 'user_id'])
      .eq('room_id', roomId)
      .map((rows) => rows.map((e) => e['user_id'].toString()).toList());

  Stream<List<MicSeat>> watchSeats(String roomId) => _db
      .from('mic_seats')
      .stream(primaryKey: ['room_id', 'seat_no'])
      .eq('room_id', roomId)
      .order('seat_no')
      .map((r) => r.map(MicSeat.fromJson).toList());
}
