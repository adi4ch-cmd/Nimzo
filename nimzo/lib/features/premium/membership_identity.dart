import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'membership_status.dart';
import 'membership_catalog.dart';
import 'membership_media_view.dart';
import 'membership_pack_runtime.dart';
import 'membership_pack_inventory.dart';
import '../store/premium_cosmetics.dart';
import '../store/cosmetic_media_view.dart';
import '../store/store_visual_equipment.dart';
import 'membership_room_background.dart';

/// Effective, expiry-checked identity from the server; cached profile tiers
/// never establish an entitlement. Dispose on navigation/account changes.
final effectiveMembershipProvider = FutureProvider.autoDispose
    .family<MembershipStatus?, String>((ref, userId) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final expiryCheck = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(expiryCheck.cancel);
  if (session.client.auth.currentSession != null) {
    final channel = session.client
        .channel('membership-appearance:$userId:${identityHashCode(ref)}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'nimzo_membership_equipment',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId),
            callback: (_) {
              ref.invalidate(storeVisualEquipmentProvider(userId));
              ref.invalidate(membershipRoomBackgroundProvider);
              ref.invalidateSelf();
            })
        .subscribe();
    ref.onDispose(() => unawaited(session.client.removeChannel(channel)));
  }
  final value = await session.client.rpc('nimzo_membership_appearance',
      params: {'p_user': userId}).timeout(const Duration(seconds: 6));
  if (value is! Map) return null;
  final status = MembershipStatus.fromJson(Map<String, dynamic>.from(value));
  final expiries = [status.vipExpiresAt, status.svipExpiresAt]
      .whereType<DateTime>()
      .where((date) => date.isAfter(status.serverNow))
      .toList();
  if (expiries.isNotEmpty) {
    expiries.sort();
    final timer =
        Timer(expiries.first.difference(status.serverNow), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return status;
});

class VerifiedMembershipIdentity extends ConsumerWidget {
  const VerifiedMembershipIdentity(
      {super.key, required this.userId, this.compact = false});
  final String userId;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = ref.watch(effectiveMembershipProvider(userId));
    final membership = effective.hasError ? null : effective.valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    if (membership.vipLevel == 0 && membership.svipLevel == 0)
      return const SizedBox.shrink();
    final remote = ref.watch(membershipPresentationsProvider);
    final bundled =
        ref.watch(membershipBundledPresentationsProvider).valueOrNull ??
            const <MembershipPresentation>[];
    Widget badge(String kind, int tier) {
      final rows = [
        ...((remote.hasError || remote.isLoading)
            ? <MembershipPresentation>[]
            : remote.valueOrNull ?? <MembershipPresentation>[]),
        ...bundled
      ];
      final matches = rows.where((row) => row.kind == kind && row.tier == tier);
      final media = matches.isEmpty ? null : matches.first.badge;
      final label = '${kind.toUpperCase()} $tier';
      return Semantics(
          label: label,
          child: media == null
              ? Text(label,
                  style: const TextStyle(
                      color: Color(0xff126647), fontWeight: FontWeight.w800))
              : SizedBox(
                  height: compact ? 14 : 32,
                  width: compact ? 32 : 48,
                  child: MembershipMediaView(
                      key: ValueKey(media.sha256), media: media)));
    }

    final kind = membership.primaryKind;
    return kind == null
        ? const SizedBox.shrink()
        : badge(kind, membership.primaryTier);
  }
}

/// Display only after the room confirms this member's join. No grant or
/// historical event replay. Native effects remain muted beside voice audio.
class VerifiedOwnMembershipEntrance extends ConsumerStatefulWidget {
  const VerifiedOwnMembershipEntrance({super.key});
  @override
  ConsumerState<VerifiedOwnMembershipEntrance> createState() =>
      _VerifiedOwnMembershipEntranceState();
}

class _VerifiedOwnMembershipEntranceState
    extends ConsumerState<VerifiedOwnMembershipEntrance> {
  String? _account;
  Widget? _joinedEntrance;
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    if (_account != id) {
      _account = id;
      _joinedEntrance = null;
    }
    if (id == null) return const SizedBox.shrink();
    final effective = ref.watch(effectiveMembershipProvider(id));
    final membership = effective.hasError ? null : effective.valueOrNull;
    if (membership == null || !membership.hasSlot('Rides'))
      return const SizedBox.shrink();
    // Capture once per confirmed room mount: publishing an effect, a periodic
    // status refresh or tier renewal must never synthesize another join event.
    if (_joinedEntrance != null) return _joinedEntrance!;
    final remote = ref.watch(membershipPresentationsProvider);
    if (remote.isLoading) return const SizedBox.shrink();
    final kind = membership.packKind!;
    final tier = membership.packTier;
    final rows = (remote.hasError
            ? <MembershipPresentation>[]
            : remote.valueOrNull ?? <MembershipPresentation>[])
        .where((row) =>
            row.kind == kind &&
            row.tier == tier &&
            row.benefits.contains('room_entry'));
    final entrance = rows.isEmpty ? null : rows.first.entrance;
    final bundledEntry = MembershipPackInventory.forTier(kind, tier)[3];
    _joinedEntrance = entrance != null
        ? IgnorePointer(
            child: MembershipMediaView(
                key: ValueKey('$id:${entrance.sha256}'),
                media: entrance,
                animate: true))
        : bundledEntry.animated
            ? _OriginalVipRoomEntry(
                key: ValueKey('$id:$kind:$tier:original-entry'),
                kind: kind,
                tier: tier,
                asset: bundledEntry.path!)
            : MembershipPackEntranceBanner(
                key: ValueKey('$id:$kind:$tier'),
                theme: MembershipPackTheme.fromStatus(membership)!);
    return _joinedEntrance!;
  }
}

/// A Hafla VIP entrance is real SVGA media, not the NIMZO drawn banner.
/// It runs once after the verified user enters the room and removes itself
/// after playback or an error. Nothing is persisted or granted here.
class _OriginalVipRoomEntry extends StatefulWidget {
  const _OriginalVipRoomEntry({
    super.key,
    required this.kind,
    required this.tier,
    required this.asset,
  });

  final String kind;
  final int tier;
  final String asset;

  @override
  State<_OriginalVipRoomEntry> createState() => _OriginalVipRoomEntryState();
}

class _OriginalVipRoomEntryState extends State<_OriginalVipRoomEntry> {
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -.5),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child: CosmeticMediaView(
            key: ValueKey('original-vip-entry-${widget.tier}'),
            media: CosmeticMedia(
              'membership-vip-entry-${widget.tier}',
              'Room Entry',
              'Verified VIP ${widget.tier} original room entry',
              widget.asset,
              CosmeticMediaKind.svga,
            ),
            animate: true,
            fit: BoxFit.contain,
            onFinished: () {
              if (mounted) setState(() => _finished = true);
            },
          ),
        ),
      ),
    );
  }
}
