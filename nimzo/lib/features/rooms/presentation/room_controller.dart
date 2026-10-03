import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/room_repository.dart';
import '../domain/room.dart';
import '../../profile/profile.dart';

final roomRepositoryProvider = Provider((ref) => RoomRepository(Supabase.instance.client));

final roomProvider = FutureProvider.family<Room, String>((ref, id) => ref.watch(roomRepositoryProvider).get(id));
final seatsProvider = StreamProvider.family<List<MicSeat>, String>((ref, id) => ref.watch(roomRepositoryProvider).watchSeats(id));
/// country == null means all countries.
final popularRoomsProvider = FutureProvider.family<List<Room>, String?>((ref, c) => ref.watch(roomRepositoryProvider).popular(country: c));
final newRoomsProvider = FutureProvider<List<Room>>((ref) => ref.watch(roomRepositoryProvider).newRooms());
final myRoomsProvider = FutureProvider<Map<String, List<Room>>>((ref) => ref.watch(roomRepositoryProvider).myRooms());

class RoomActions {
  final Ref _ref;
  RoomActions(this._ref);
  RoomRepository get _r => _ref.read(roomRepositoryProvider);
  Future<void> enter(String id, {String? password}) => _r.join(id, password: password);
  Future<void> exit(String id) => _r.leave(id);
  Future<void> seat(String id, int n) => _r.takeSeat(id, n);
  Future<void> unseat(String id) => _r.leaveSeat(id);
}

final roomActionsProvider = Provider((ref) => RoomActions(ref));


final roomSeatProfilesProvider = FutureProvider.family<Map<String, Profile>, String>((ref, roomId) async {
  final seats = ref.watch(seatsProvider(roomId)).valueOrNull ?? const <MicSeat>[];
  final ids = seats.map((s) => s.userId).whereType<String>().toSet().toList();
  if (ids.isEmpty) return const {};
  final rows = await ref.read(roomRepositoryProvider).profilesForUsers(ids);
  return {for (final p in rows) p.id: p};
});

final roomOwnerProfileProvider = FutureProvider.family<Profile?, String>((ref, roomId) async {
  final room = await ref.watch(roomProvider(roomId).future);
  final rows = await ref.read(roomRepositoryProvider).profilesForUsers([room.ownerId]);
  return rows.isEmpty ? null : rows.first;
});
