import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../store/premium_cosmetics.dart';

/// Presentation only. Membership entitlements, purchases, expiry and rewards
/// remain server-evaluated by vip_status / phoenix_membership.
class NimzoMembershipMedia {
  const NimzoMembershipMedia({
    required this.kind,
    required this.tier,
    required this.slot,
    required this.url,
    required this.mediaKind,
    this.thumbnailUrl,
  });

  final String kind, slot, url;
  final int tier;
  final CosmeticMediaKind mediaKind;
  final String? thumbnailUrl;

  static const slots = {
    'hero', 'badge', 'avatar_frame', 'entry', 'nameplate', 'chat_bubble',
    'mic_wave', 'room_background', 'privilege', 'expiration',
  };

  static bool safeHttps(Object? raw) {
    if (raw is! String || raw.length > 2048) return false;
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' &&
        uri.host.isNotEmpty && uri.userInfo.isEmpty && uri.fragment.isEmpty;
  }

  static NimzoMembershipMedia? fromRow(Map<String, dynamic> row) {
    final kind = row['kind'];
    final tier = row['tier'];
    final slot = row['slot'];
    final url = row['asset_url'];
    if (kind != 'vip' && kind != 'svip') return null;
    if (tier is! num || tier.toInt() < 1 || tier.toInt() > 10 ||
        tier.toDouble() != tier.toInt().toDouble()) return null;
    if (slot is! String || !slots.contains(slot) || !safeHttps(url)) return null;

    final mediaKind = switch (row['media_kind']) {
      'image' => CosmeticMediaKind.image,
      'svga' => CosmeticMediaKind.svga,
      'vap' => CosmeticMediaKind.vap,
      _ => null,
    };
    if (mediaKind == null) return null;
    if (slot == 'entry' && mediaKind == CosmeticMediaKind.image) return null;
    if (slot != 'entry' && mediaKind == CosmeticMediaKind.vap) return null;

    final thumb = row['thumbnail_url'];
    return NimzoMembershipMedia(
      kind: kind as String,
      tier: tier.toInt(),
      slot: slot,
      url: url as String,
      mediaKind: mediaKind,
      thumbnailUrl: safeHttps(thumb) ? thumb as String : null,
    );
  }

  CosmeticMedia toCosmetic() => CosmeticMedia(
        'membership-$kind-$tier-$slot',
        slot,
        '${kind.toUpperCase()} $tier $slot',
        url,
        mediaKind,
        thumbnail: thumbnailUrl,
      );
}

final nimzoMembershipMediaProvider =
    FutureProvider.autoDispose<List<NimzoMembershipMedia>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return const [];
  final rows = await session.client
      .from('nimzo_membership_media')
      .select('kind,tier,slot,asset_url,media_kind,thumbnail_url')
      .eq('approved', true)
      .limit(200);
  return rows
      .map((row) => NimzoMembershipMedia.fromRow(
          Map<String, dynamic>.from(row)))
      .whereType<NimzoMembershipMedia>()
      .toList(growable: false);
});

Map<String, NimzoMembershipMedia> membershipTierMedia(
  List<NimzoMembershipMedia> media,
  String kind,
  int tier,
) {
  if (kind != 'vip' && kind != 'svip') return const {};
  if (tier < 1 || tier > 10) return const {};
  return {
    for (final item in media)
      if (item.kind == kind && item.tier == tier) item.slot: item,
  };
}
