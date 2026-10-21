import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'membership_status.dart';
import 'willchill_membership_badges.dart';
import 'willchill_own_svip_entrance.dart';

/// Effective, expiry-checked identity from the server; cached profile tiers
/// never establish an entitlement. Dispose on navigation/account changes.
final effectiveMembershipProvider = FutureProvider.autoDispose
    .family<MembershipStatus?, String>((ref, userId) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final value = await session.client.rpc('phoenix_membership',
      params: {'p_user': userId}).timeout(const Duration(seconds: 6));
  if (value is! Map) return null;
  return MembershipStatus.fromJson(Map<String, dynamic>.from(value));
});

class VerifiedMembershipIdentity extends ConsumerWidget {
  const VerifiedMembershipIdentity({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership =
        ref.watch(effectiveMembershipProvider(userId)).valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    return WillChillMembershipBadges(
        vipLevel: membership.vipLevel, svipLevel: membership.svipLevel);
  }
}

/// Display only after the room confirms this member's join. No grant or
/// historical event replay. Native effects remain muted beside voice audio.
class VerifiedOwnMembershipEntrance extends ConsumerWidget {
  const VerifiedOwnMembershipEntrance({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserIdProvider);
    if (id == null) return const SizedBox.shrink();
    final membership = ref.watch(effectiveMembershipProvider(id)).valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    final svip = membership.svipLevel;
    if (svip >= 1 && svip <= 8) {
      return WillChillOwnSvipEntrance(
          key: ValueKey('$id:$svip'), svipLevel: svip);
    }
    if (svip == 0 && membership.vipLevel == 0) return const SizedBox.shrink();
    return _OriginalMembershipEntrance(
        key: ValueKey('$id:$svip:${membership.vipLevel}'),
        label: svip > 0 ? 'SVIP $svip' : 'VIP ${membership.vipLevel}');
  }
}

class _OriginalMembershipEntrance extends StatelessWidget {
  const _OriginalMembershipEntrance({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -.6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(seconds: 3),
            builder: (_, progress, child) => Opacity(
              opacity: progress < .2
                  ? progress / .2
                  : progress > .8
                      ? (1 - progress) / .2
                      : 1,
              child: Transform.translate(
                  offset: Offset(0, -18 * progress), child: child),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0xff143c30),
                  border: Border.all(color: const Color(0xffffd270)),
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('$label · Welcome to the room',
                      style: const TextStyle(
                          color: Color(0xffffd270),
                          fontWeight: FontWeight.w800))),
            ),
          ),
        ),
      );
}
