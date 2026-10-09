import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../profile/profile_collections.dart';
import '../profile/profile_presentation.dart';

class HonorWallContent extends ConsumerWidget {
  const HonorWallContent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserIdProvider);
    if (id == null) return const EmptyContent('Sign in to view your honors.');
    final key = (id, ProfileCollection.medal);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your medals', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      AsyncContent(
          value: ref.watch(profileCollectionProvider(key)),
          onRetry: () => ref.invalidate(profileCollectionProvider(key)),
          builder: (items) => items.isEmpty
              ? const EmptyContent('No earned medals yet.')
              : Wrap(spacing: 16, runSpacing: 16, children: [
                  for (final item in items)
                    SizedBox(
                        width: 90,
                        child: Column(children: [
                          CollectibleArtwork(item: item, size: 84),
                          Text(item['name']?.toString() ?? 'Medal',
                              textAlign: TextAlign.center)
                        ]))
                ])),
      const SizedBox(height: 12),
      ListTile(
        leading: const Icon(Icons.emoji_events_outlined),
        title: const Text('Game Level Medals'),
        subtitle: const Text('Only verified game results count'),
        onTap: () => context.push('/game-level'),
      ),
      const SizedBox(height: 20),
      const Text('Room medal previews',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const Text(
          'Room medal awards require an approved server eligibility contract.'),
      const SizedBox(height: 10),
      const Wrap(spacing: 10, children: [
        ReferenceArtwork('rmed', 0, size: 90),
        ReferenceArtwork('rmed', 1, size: 90)
      ]),
    ]);
  }
}
