import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';
import 'membership_identity.dart';
import '../store/store_visual_equipment.dart';

final membershipRoomBackgroundProvider = FutureProvider.autoDispose
    .family<({String kind, int tier})?, String>((ref, roomId) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  if (session.client.auth.currentSession != null) {
    final channel = session.client
        .channel('membership-room:$roomId:${identityHashCode(ref)}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'nimzo_membership_room_background',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: roomId),
            callback: (_) {
              ref.invalidate(storeVisualEquipmentProvider);
              ref.invalidateSelf();
            })
        .subscribe();
    ref.onDispose(() => unawaited(session.client.removeChannel(channel)));
  }
  final value = await session.client.rpc('nimzo_membership_room_appearance',
      params: {'p_room': roomId}).timeout(const Duration(seconds: 6));
  if (value is! Map || value['kind'] is! String || value['tier'] is! num)
    return null;
  return (kind: value['kind'] as String, tier: (value['tier'] as num).toInt());
});

class MembershipRoomBackgroundControls extends ConsumerStatefulWidget {
  const MembershipRoomBackgroundControls(
      {super.key, required this.roomId, required this.ownerId});
  final String roomId;
  final String? ownerId;
  @override
  ConsumerState<MembershipRoomBackgroundControls> createState() =>
      _MembershipRoomBackgroundControlsState();
}

class _MembershipRoomBackgroundControlsState
    extends ConsumerState<MembershipRoomBackgroundControls> {
  bool busy = false;
  String? error;
  Future<void> change(bool apply) async {
    final session = ref.read(sessionSupabaseProvider);
    if (busy || session.userId != widget.ownerId) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await session.client
          .rpc('nimzo_membership_set_room_background', params: {
        'p_room': widget.roomId,
        'p_apply': apply
      }).timeout(const Duration(seconds: 15));
      if (result != true) throw StateError('Background not confirmed');
    } catch (_) {
      if (mounted)
        setState(() => error = 'Room background update not confirmed. Retry.');
    } finally {
      if (mounted) {
        ref.invalidate(membershipRoomBackgroundProvider(widget.roomId));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    if (me == null || me != widget.ownerId) return const SizedBox.shrink();
    final member = ref.watch(effectiveMembershipProvider(me)).valueOrNull;
    if (member?.packKind != 'vip' || member?.packTier != 6)
      return const SizedBox.shrink();
    final applied = ref
            .watch(membershipRoomBackgroundProvider(widget.roomId))
            .valueOrNull !=
        null;
    return Column(children: [
      TextButton.icon(
          onPressed: busy ? null : () => change(!applied),
          icon: const Icon(Icons.wallpaper, size: 16),
          label: Text(busy
              ? 'Saving background…'
              : applied
                  ? 'Remove VIP 6 room background'
                  : 'Apply VIP 6 room background')),
      if (error != null)
        Text(error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
    ]);
  }
}
