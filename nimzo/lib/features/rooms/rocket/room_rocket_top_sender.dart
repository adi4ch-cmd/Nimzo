import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';

class RocketTopSender {
  const RocketTopSender({
    required this.userId,
    required this.name,
    required this.nimzoId,
    required this.giftedCoins,
    this.avatarPath,
  });
  final String userId, name;
  final int nimzoId, giftedCoins;
  final String? avatarPath;

  factory RocketTopSender.fromJson(Map<String, dynamic> value) {
    if (value['user_id'] is! String ||
        value['name'] is! String ||
        value['nimzo_id'] is! int ||
        value['gifted_coins'] is! int) {
      throw const FormatException('Invalid Rocket Top 1 event sender');
    }
    return RocketTopSender(
      userId: value['user_id'] as String,
      name: value['name'] as String,
      nimzoId: value['nimzo_id'] as int,
      giftedCoins: value['gifted_coins'] as int,
      avatarPath: value['avatar_path'] as String?,
    );
  }
}

class RoomRocketTopSenderRepository {
  const RoomRocketTopSenderRepository(this.db);
  final SupabaseClient db;
  Future<RocketTopSender?> getForEvent(String eventId) async {
    final raw = await db.rpc(
      'room_rocket_event_winner',
      params: {'p_event': eventId},
    );
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Invalid Rocket event winner');
    }
    return RocketTopSender.fromJson(Map<String, dynamic>.from(raw));
  }
}

final roomRocketTopSenderRepositoryProvider = Provider(
  (ref) => RoomRocketTopSenderRepository(
    ref.watch(sessionSupabaseProvider).client,
  ),
);

final roomRocketTopSenderProvider =
    FutureProvider.autoDispose.family<RocketTopSender?, String>(
  (ref, eventId) =>
      ref.watch(roomRocketTopSenderRepositoryProvider).getForEvent(eventId),
);
