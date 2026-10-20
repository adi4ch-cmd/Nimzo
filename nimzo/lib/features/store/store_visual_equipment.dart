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
      return {
        for (final row in rows as List)
          if (premiumCosmetics[row['item_id']] case final CosmeticMedia media)
            if (media.category == row['category']) media.category: media,
      };
    });

class EquippedCosmetic extends ConsumerWidget {
  const EquippedCosmetic({
    super.key,
    required this.userId,
    required this.category,
    required this.child,
    this.fit = BoxFit.cover,
  });
  final String? userId;
  final String category;
  final Widget child;
  final BoxFit fit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) return child;
    final media = ref
        .watch(storeVisualEquipmentProvider(userId!))
        .valueOrNull?[category];
    if (media == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: media.kind == CosmeticMediaKind.image
                ? Image.asset(
                    media.asset,
                    fit: category == 'Profile Card' ? BoxFit.fill : fit,
                  )
                : CosmeticMediaView(key: ValueKey(media.id), media: media),
          ),
        ),
        if (category == 'Profile Card')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            ),
          )
        else
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
  });
  final String userId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: child,
            ),
          ),
        ),
        if (badge != null)
          SizedBox(
            width: 32,
            height: 32,
            child: CosmeticMediaView(key: ValueKey(badge.id), media: badge),
          ),
      ],
    );
  }
}
