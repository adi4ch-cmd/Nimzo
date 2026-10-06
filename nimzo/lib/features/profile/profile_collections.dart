import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../gifts/gift_artwork.dart';

enum ProfileCollection {
  medal('Medal Wall'),
  frame('Frames'),
  car('Cars');

  final String title;
  const ProfileCollection(this.title);
}

final profileCollectionProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, ProfileCollection)>(
        (ref, key) async {
  final rows = <Map<String, dynamic>>[];
  for (var start = 0;; start += 200) {
    final page = await ref
        .watch(supabaseProvider)
        .from('profile_owned_collectibles')
        .select(
            'granted_at,expires_at,profile_collectibles!inner(id,kind,name,image_path,description)')
        .eq('user_id', key.$1)
        .eq('profile_collectibles.kind', key.$2.name)
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}')
        .order('granted_at', ascending: false)
        .order('collectible_id')
        .range(start, start + 199);
    rows.addAll(page.map(
        (r) => Map<String, dynamic>.from(r['profile_collectibles'] as Map)));
    if (page.length < 200) return rows;
  }
});

class ProfileCollectionSection extends ConsumerWidget {
  final String userId;
  final ProfileCollection kind;
  final bool full;
  const ProfileCollectionSection(
      {super.key, required this.userId, required this.kind, this.full = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (userId, kind);
    final content = ref.watch(profileCollectionProvider(key)).when(
          loading: () => const Padding(
              padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(profileCollectionProvider(key)),
              child: Text('Retry loading ${kind.title}')),
          data: (items) => items.isEmpty
              ? Text(
                  'No ${kind == ProfileCollection.medal ? 'medals earned' : '${kind.title.toLowerCase()} owned'} yet')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final item in full ? items : items.take(5))
                          SizedBox(
                              width: 90,
                              child: Column(children: [
                                GiftArtwork(
                                    path: item['image_path'] as String?,
                                    bucket: 'profile-collectibles',
                                    size: 64),
                                Text(item['name'] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ])),
                      ]),
                      if (!full)
                        TextButton(
                            onPressed: () => Navigator.of(context)
                                    .push(MaterialPageRoute<void>(
                                  builder: (_) => Scaffold(
                                      appBar: AppBar(title: Text(kind.title)),
                                      body: SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: ProfileCollectionSection(
                                              userId: userId,
                                              kind: kind,
                                              full: true))),
                                )),
                            child: Text('View All ${kind.title}')),
                    ]),
        );
    return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!full) ...[
            Text(kind.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12)
          ],
          content,
        ]));
  }
}
