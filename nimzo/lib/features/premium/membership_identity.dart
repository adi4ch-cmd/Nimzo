import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'membership_status.dart';
import 'membership_catalog.dart';
import 'membership_media_view.dart';
import 'membership_pack_runtime.dart';

/// Effective, expiry-checked identity from the server; cached profile tiers
/// never establish an entitlement. Dispose on navigation/account changes.
final effectiveMembershipProvider = FutureProvider.autoDispose
    .family<MembershipStatus?, String>((ref, userId) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final expiryCheck = Timer.periodic(const Duration(minutes: 1), (_) => ref.invalidateSelf());
  ref.onDispose(expiryCheck.cancel);
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
    final effective = ref.watch(effectiveMembershipProvider(userId));
    final membership = effective.hasError ? null : effective.valueOrNull;
    if (membership == null) return const SizedBox.shrink();
    if (membership.vipLevel == 0 && membership.svipLevel == 0) return const SizedBox.shrink();
    final remote = ref.watch(membershipPresentationsProvider);
    final bundled = ref.watch(membershipBundledPresentationsProvider).valueOrNull ?? const <MembershipPresentation>[];
    Widget badge(String kind, int tier) {
      final rows = [...((remote.hasError || remote.isLoading) ? <MembershipPresentation>[] : remote.valueOrNull ?? <MembershipPresentation>[]), ...bundled];
      final matches = rows.where((row) => row.kind == kind && row.tier == tier);
      final media = matches.isEmpty ? null : matches.first.badge;
      final label = '${kind.toUpperCase()} $tier';
      return Semantics(label: label, child: media == null
        ? Text(label, style: const TextStyle(color: Color(0xff126647), fontWeight: FontWeight.w800))
        : SizedBox(height: 32, width: 48, child: MembershipMediaView(key: ValueKey(media.sha256), media: media)));
    }
    return Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (membership.vipLevel > 0) badge('vip', membership.vipLevel),
      if (membership.svipLevel > 0) badge('svip', membership.svipLevel),
    ]);
  }
}

/// Display only after the room confirms this member's join. No grant or
/// historical event replay. Native effects remain muted beside voice audio.
class VerifiedOwnMembershipEntrance extends ConsumerStatefulWidget {
  const VerifiedOwnMembershipEntrance({super.key});
  @override
  ConsumerState<VerifiedOwnMembershipEntrance> createState() => _VerifiedOwnMembershipEntranceState();
}
class _VerifiedOwnMembershipEntranceState extends ConsumerState<VerifiedOwnMembershipEntrance> {
  String? _account;
  Widget? _joinedEntrance;
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    if (_account != id) { _account = id; _joinedEntrance = null; }
    if (id == null) return const SizedBox.shrink();
    final effective = ref.watch(effectiveMembershipProvider(id));
    final membership = effective.hasError ? null : effective.valueOrNull;
    if (membership == null || (membership.vipLevel == 0 && membership.svipLevel == 0)) return const SizedBox.shrink();
    // Capture once per confirmed room mount: publishing an effect, a periodic
    // status refresh or tier renewal must never synthesize another join event.
    if (_joinedEntrance != null) return _joinedEntrance!;
    final remote = ref.watch(membershipPresentationsProvider);
    if (remote.isLoading) return const SizedBox.shrink();
    final svip = membership.svipLevel;
    final kind = svip > 0 ? 'svip' : 'vip';
    final tier = svip > 0 ? svip : membership.vipLevel;
    final rows = (remote.hasError ? <MembershipPresentation>[] : remote.valueOrNull ?? <MembershipPresentation>[])
      .where((row) => row.kind == kind && row.tier == tier && row.benefits.contains('room_entry'));
    final entrance = rows.isEmpty ? null : rows.first.entrance;
    _joinedEntrance = entrance == null
      ? MembershipPackEntranceBanner(key: ValueKey('$id:$kind:$tier'),
          theme: MembershipPackTheme.fromStatus(membership)!)
      : IgnorePointer(child: MembershipMediaView(key: ValueKey('$id:${entrance.sha256}'), media: entrance, animate: true));
    return _joinedEntrance!;
  }
}

