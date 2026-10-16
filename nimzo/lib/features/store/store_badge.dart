import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_repository.dart';

/// Server-backed medal equipped for a given user, not a guessed tier or fake
/// achievement. The bag respects expiration and store equip authorization.
final equippedRoyalMedalProvider = FutureProvider.family<RoyalBagItem?, String>(
  (ref, id) async {
    final bag = await ref.watch(royalBagProvider(id).future);
    for (final item in bag) {
      if (item.equipped) return item;
    }
    return null;
  },
);

class EquippedRoyalMedal extends ConsumerWidget {
  final String userId;
  final bool compact;
  final bool onDark;

  const EquippedRoyalMedal({
    super.key,
    required this.userId,
    this.compact = false,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(equippedRoyalMedalProvider(userId));
    return selected.maybeWhen(
      data: (item) {
        if (item == null) return const SizedBox.shrink();
        return Tooltip(
          key: ValueKey('equipped-medal-$userId'),
          message: 'Equipped medal: ${item.name}',
          child: Semantics(
            label: 'Equipped medal: ${item.name}',
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 2 : 6,
                horizontal: compact ? 4 : 8,
              ),
              decoration: BoxDecoration(
                color: onDark ? const Color(0x66502414) : const Color(0xfffff7e8),
                borderRadius: BorderRadius.circular(compact ? 12 : 16),
                border: Border.all(
                  color: onDark ? const Color(0xffd7b77a) : const Color(0xffe4c58f),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    item.image,
                    key: ValueKey('equipped-medal-art-$userId'),
                    width: compact ? 23 : 35,
                    height: compact ? 23 : 35,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.workspace_premium,
                          size: compact ? 20 : 30,
                          color: onDark ? const Color(0xffffd991)
                                       : const Color(0xffa87421)),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    SizedBox(width: 120, child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff725018)),
                    )),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      // Do not draw a made-up badge before the authenticated bag loads.
      orElse: () => const SizedBox.shrink(),
    );
  }
}
