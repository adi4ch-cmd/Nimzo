import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_handler.dart';
import '../domain/room.dart';

class RoomRepository {
  final SupabaseClient _db;
  RoomRepository(this._db);

  Future<List<Room>> popular({String? country}) async {
    try {
      var q = _db.from('rooms_ranked').select().eq('status', 'open');
      if (country != null) q = q.eq('country', country);
      final rows = await q.order('member_count', ascending: false).limit(50);
      return rows.map(Room.fromJson).toList();
    } catch (e) { throw mapError(e); }
  }

  Future<List<Room>> newRooms() =>
      _list(since: DateTime.now().subtract(const Duration(days: 15)));

  Future<List<Room>> _list({String? country, DateTime? since}) async {
    try {
      var q = _db.from('rooms').select().eq('status', 'open');
      if (country != null) q = q.eq('country', country);
      if (since != null) q = q.gte('created_at', since.toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(50);
      return rows.map(Room.fromJson).toList();
    } catch (e) { throw mapError(e); }
  }

  Future<Map<String, List<Room>>> myRooms() async {
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('my_rooms'));
      List<Room> l(String k) => (r[k] as List? ?? [])
          .map((e) => Room.fromJson(Map<String, dynamic>.from(e))).toList();
      return {'recent': l('recent'), 'followed': l('followed')};
    } catch (e) { throw mapError(e); }
  }

  Future<void> followRoom(String id, bool on) async {
    try { await _db.rpc('follow_room', params: {'p_room': id, 'p_on': on}); }
    catch (e) { throw mapError(e); }
  }

  Future<Room> get(String id) async {
    try { return Room.fromJson(await _db.from('rooms').select().eq('id', id).single()); }
    catch (e) { throw mapError(e); }
  }

  /// Room creation is performed by the SECURITY DEFINER RPC so the owner,
  /// ten mic seats and membership are initialized atomically server-side.
  Future<String> create(String name, {String? country, String? password}) async {
    try {
      final id = await _db.rpc('create_room', params: {
        'p_name': name,
        'p_country': country,
        'p_password': password,
      });
      return id.toString();
    } catch (e) { throw mapError(e); }
  }

  Future<void> join(String roomId, {String? password}) =>
      _rpc('join_room', {'p_room': roomId, 'p_password': password});
  Future<void> leave(String roomId) => _rpc('leave_room', {'p_room': roomId});
  Future<void> takeSeat(String roomId, int seat) =>
      _rpc('take_seat', {'p_room': roomId, 'p_seat': seat});
  Future<void> leaveSeat(String roomId) => _rpc('leave_seat', {'p_room': roomId});
  Future<void> modMuteSeat(String roomId, int seat, bool muted) =>
      _rpc('mod_mute_seat', {'p_room': roomId, 'p_seat': seat, 'p_muted': muted});
  Future<void> kick(String roomId, String userId) =>
      _rpc('kick_member', {'p_room': roomId, 'p_user': userId});

  Future<void> _rpc(String fn, Map<String, dynamic> args) async {
    try { await _db.rpc(fn, params: args); } catch (e) { throw mapError(e); }
  }

  Stream<List<MicSeat>> watchSeats(String roomId) => _db
      .from('mic_seats').stream(primaryKey: ['room_id', 'seat_no'])
      .eq('room_id', roomId)
      .order('seat_no')
      .map((r) => r.map(MicSeat.fromJson).toList());
}
