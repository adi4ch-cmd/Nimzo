import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/nimzo_user_card.dart';
import 'profile.dart';

enum ProfileSocialList { following, followers, visitors }

final profileSocialListProvider = FutureProvider.autoDispose
    .family<List<Profile>, (String, ProfileSocialList)>((ref, key) async {
  final db = ref.watch(supabaseProvider);
  final (id, kind) = key;
  final String table, owner, related, order;
  switch (kind) {
    case ProfileSocialList.following:
      table = 'follows';
      owner = 'follower_id';
      related = 'followee_id';
      order = 'created_at';
    case ProfileSocialList.followers:
      table = 'follows';
      owner = 'followee_id';
      related = 'follower_id';
      order = 'created_at';
    case ProfileSocialList.visitors:
      table = 'visitors';
      owner = 'profile_id';
      related = 'visitor_id';
      order = 'visited_at';
  }
  // Fetch every page; do not silently truncate a user's collection at 50/1000.
  final ids = <String>[];
  for (var start = 0;; start += 200) {
    final rows = await db
        .from(table)
        .select(related)
        .eq(owner, id)
        .order(order, ascending: false)
        .order(related)
        .range(start, start + 199);
    ids.addAll(rows.map((r) => r[related] as String));
    if (rows.length < 200) break;
  }
  final unique = ids.toSet().toList();
  final users = <String, Profile>{};
  for (var start = 0; start < unique.length; start += 100) {
    final batch = unique.skip(start).take(100).toList();
    final rows = await db.from('profiles').select().inFilter('id', batch);
    for (final row in rows) {
      final user = Profile.fromJson(row);
      users[user.id] = user;
    }
  }
  return [
    for (final id in unique)
      if (users[id] != null) users[id]!
  ];
});

class ProfileSocialScreen extends ConsumerWidget {
  final String userId;
  final ProfileSocialList kind;
  const ProfileSocialScreen(
      {super.key, required this.userId, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (userId, kind);
    final title = switch (kind) {
      ProfileSocialList.following => 'Following',
      ProfileSocialList.followers => 'Followers',
      ProfileSocialList.visitors => 'Visitors',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ref.watch(profileSocialListProvider(key)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => ErrorView(
                message: '$title could not be loaded.',
                onRetry: () => ref.invalidate(profileSocialListProvider(key))),
            data: (users) => users.isEmpty
                ? Center(child: Text('No ${title.toLowerCase()} yet'))
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(profileSocialListProvider(key));
                      await ref.read(profileSocialListProvider(key).future);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (_, i) => NimzoUserCard(
                          user: users[i],
                          avatarUrl: storageUrl(ref.watch(supabaseProvider),
                              'avatars', users[i].avatarPath),
                          onTap: () => context.push('/profile/${users[i].id}')),
                    ),
                  ),
          ),
    );
  }
}
