import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../diamond/room_diamond_repository.dart';

/// Display-only leaderboard. Results come from the server, not local wallet
/// calculations. No prize is granted by fetching or viewing this list.
class RoomRocketLeader {
  const RoomRocketLeader({
    required this.rank,
    required this.userId,
    required this.nimzoId,
    required this.displayName,
    required this.giftedCoins,
    this.avatarPath,
  });

  final int rank;
  final String userId;
  final int nimzoId;
  final String displayName;
  final String? avatarPath;
  final int giftedCoins;

  factory RoomRocketLeader.fromJson(Map<String, dynamic> data) {
    final rank = data['rank'];
    final coins = data['gifted_coins'];
    final id = data['user_id'];
    final nimzoId = data['nimzo_id'];
    if (rank is! int ||
        rank < 1 ||
        rank > 3 ||
        coins is! int ||
        coins < 0 ||
        id is! String ||
        id.isEmpty ||
        nimzoId is! int ||
        data['display_name'] is! String) {
      throw const FormatException('Invalid Rocket leaderboard result');
    }
    return RoomRocketLeader(
      rank: rank,
      userId: id,
      nimzoId: nimzoId,
      displayName: data['display_name'] as String,
      giftedCoins: coins,
      avatarPath: data['avatar_path'] as String?,
    );
  }
}

class RoomRocketLeaderboardRepository {
  const RoomRocketLeaderboardRepository(this.db);
  final SupabaseClient db;

  Future<List<RoomRocketLeader>> leaders(String roomId) async {
    final raw =
        await db.rpc('room_rocket_leaderboard', params: {'p_room': roomId});
    if (raw is! Map) {
      throw const FormatException('Rocket leaderboard unavailable');
    }
    final leaders = raw['leaders'];
    if (leaders is! List || leaders.length > 3) {
      throw const FormatException('Invalid Rocket leaderboard length');
    }
    final parsed = <RoomRocketLeader>[];
    for (final leader in leaders) {
      if (leader is! Map) {
        throw const FormatException('Invalid Rocket leaderboard entry');
      }
      parsed.add(RoomRocketLeader.fromJson(
        Map<String, dynamic>.from(leader),
      ));
    }
    return parsed;
  }
}

final roomRocketLeaderboardRepositoryProvider = Provider(
  (ref) => RoomRocketLeaderboardRepository(
    ref.watch(sessionSupabaseProvider).client,
  ),
);

final roomRocketLeaderboardProvider = FutureProvider.autoDispose
    .family<List<RoomRocketLeader>, String>((ref, roomId) {
  // The same settled gift event stream refreshes both totals and podium.
  ref.watch(roomDiamondEventsProvider(roomId));
  return ref.watch(roomRocketLeaderboardRepositoryProvider).leaders(roomId);
});
