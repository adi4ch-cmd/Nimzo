import '../../core/services/media_publication.dart';
import '../../core/widgets/published_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'premium_cosmetics.dart';
import 'cosmetic_media_view.dart';

final storeVisualEquipmentProvider = FutureProvider.autoDispose
    .family<Map<String, CosmeticMedia>, String>((ref, userId) async {
  if (userId.isEmpty) return {};
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return {};
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final rows = await session.client.rpc(
    'nimzo_store_visual_equipment',
    params: {
      'p_user_ids': [userId],
    },
  );
  // New approved Store items need functioning equipment; never render
  // unapproved files or use catalog metadata to award ownership.
  final equippedIds = (rows as List)
      .whereType<Map>()
      .map((row) => row['item_id'])
      .whereType<String>()
      .toSet()
      .toList(growable: false);
  if (equippedIds.isEmpty) return {};
  final remote = await session.client
      .from('nimzo_cosmetic_media')
      .select()
      .inFilter('item_id', equippedIds)
      .eq('approved', true)
      .limit(100);
  final approved = <String, Map<String, dynamic>>{
    for (final entry in remote)
      if (entry['item_id'] is String)
        entry['item_id'] as String: Map<String, dynamic>.from(entry),
  };
  final equipped = <String, CosmeticMedia>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final itemId = row['item_id'];
    final category = row['category'];
    if (itemId is! String || category is! String) continue;
    final entry = approved[itemId];
    final asset = entry?['asset_url'];
    final thumbnail = entry?['thumbnail_url'];
    final kind = switch (entry?['media_kind']) {
      'image' => CosmeticMediaKind.image,
      'svga' => CosmeticMediaKind.svga,
      'vap' => CosmeticMediaKind.vap,
      _ => null,
    };
    final url = Uri.tryParse(asset is String ? asset : '');
    if (url != null &&
        url.scheme == 'https' &&
        url.host.isNotEmpty &&
        url.userInfo.isEmpty &&
        kind != null) {
      final publication =
          parseMediaPublication(entry!, kind: entry['media_kind'] as String);
      final thumbnailPublication =
          parseMediaPublication(entry, kind: 'image', prefix: 'thumbnail_');
      equipped[category] = CosmeticMedia(
        itemId,
        category,
        itemId,
        url.toString(),
        kind,
        publication: publication,
        thumbnailPublication: thumbnailPublication,
        thumbnail: thumbnail is String &&
                Uri.tryParse(thumbnail)?.scheme == 'https' &&
                (publication == null || thumbnailPublication != null)
            ? thumbnail
            : null,
      );
      continue;
    }
    // Bundled originals remain safe fallbacks and still equip normally.
    if (premiumCosmetics[itemId] case final CosmeticMedia fallback) {
      if (fallback.category == category) equipped[category] = fallback;
    }
  }
  return equipped;
});

class EquippedCosmetic extends ConsumerWidget {
  const EquippedCosmetic({
    super.key,
    required this.userId,
    required this.category,
    required this.child,
    this.fit = BoxFit.cover,
    this.enabled = true,
  });
  final String? userId;
  final String category;
  final Widget child;
  final BoxFit fit;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled || userId == null || userId!.isEmpty) return child;
    final media =
        ref.watch(storeVisualEquipmentProvider(userId!)).valueOrNull?[category];
    if (media == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: media.kind == CosmeticMediaKind.image
                ? (Uri.tryParse(media.asset)?.scheme == 'https'
                    ? PublishedImage(
                        url: media.asset,
                        publication: media.publication,
                        fit: category == 'Profile Card' ? BoxFit.fill : fit,
                        unavailable: const SizedBox.shrink(),
                      )
                    : Image.asset(
                        media.asset,
                        fit: category == 'Profile Card' ? BoxFit.fill : fit,
                      ))
                : CosmeticMediaView(
                    key: ValueKey(media.id),
                    media: media,
                    fit: category == 'ID Frame' ? BoxFit.fill : BoxFit.contain,
                    animate: !MediaQuery.disableAnimationsOf(context)),
          ),
        ),
        child,
      ],
    );
  }
}

class EquippedAvatar extends ConsumerWidget {
  const EquippedAvatar({
    super.key,
    required this.userId,
    required this.child,
    required this.size,
    this.speaking = false,
  });
  final String? userId;
  final Widget child;
  final double size;
  final bool speaking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = userId == null
        ? null
        : ref.watch(storeVisualEquipmentProvider(userId!)).valueOrNull;
    final frame = appearance?['Avatar Frame'];
    final wave = speaking ? (appearance?['Mic Wave']) : null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          for (final media in [frame, wave])
            if (media != null)
              Positioned.fill(
                left: -size * .15,
                right: -size * .15,
                top: -size * .15,
                bottom: -size * .15,
                child: IgnorePointer(
                  child: CosmeticMediaView(
                    key: ValueKey(media.id),
                    media: media,
                    animate: !MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class EquippedIdentity extends ConsumerWidget {
  const EquippedIdentity({
    super.key,
    required this.userId,
    required this.child,
    this.compact = false,
  });
  final String userId;
  final Widget child;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return child;
    final badge = ref
        .watch(storeVisualEquipmentProvider(userId))
        .valueOrNull?['Royal Badge'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: EquippedCosmetic(
            userId: userId,
            category: 'ID Frame',
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 2 : 8, vertical: compact ? 1 : 3),
              child: child,
            ),
          ),
        ),
        if (badge != null)
          SizedBox(
            width: compact ? 12 : 32,
            height: compact ? 12 : 32,
            child: CosmeticMediaView(
                key: ValueKey(badge.id),
                media: badge,
                animate: !MediaQuery.disableAnimationsOf(context)),
          ),
      ],
    );
  }
}
