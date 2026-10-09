import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_repository.dart';

final equippedRoyalMedalProvider = FutureProvider.family<RoyalBagItem?, String>(
  (ref, id) async {
    final bag = await ref.watch(royalStoreRepositoryProvider).bag(id);
    for (final item in bag) {
      if (item.equipped) return item;
    }
    return null;
  },
);

class EquippedRoyalMedal extends ConsumerWidget {
  final String userId;
  const EquippedRoyalMedal({super.key, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(equippedRoyalMedalProvider(userId))
      .maybeWhen(
        data: (item) => item == null
            ? const SizedBox.shrink()
            : Tooltip(
                message: 'Equipped: ${item.name}',
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        item.image,
                        width: 37,
                        height: 37,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        orElse: () => const SizedBox.shrink(),
      );
}
