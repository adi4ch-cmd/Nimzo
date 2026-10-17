import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_repository.dart';
import 'social_repositories.dart';

final tinglePeopleProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, tab) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final db = ref.watch(sessionSupabaseProvider).client;
  if (tab == 0) {
    final rows = await db.from('friendships')
      .select('requester_id,addressee_id')
      .eq('status', 'accepted')
      .or('requester_id.eq.$uid,addressee_id.eq.$uid')
      .limit(300);
    return rows.map((row) => row['requester_id'].toString() == uid
      ? row['addressee_id'].toString()
      : row['requester_id'].toString()).toSet().toList();
  }
  final field = tab == 1 ? 'followee_id' : 'follower_id';
  final current = tab == 1 ? 'follower_id' : 'followee_id';
  final rows = await db.from('follows').select(field)
    .eq(current, uid).limit(300);
  return rows.map((row) => row[field].toString()).toSet().toList();
});

class TingleFriendsScreen extends ConsumerStatefulWidget {
  const TingleFriendsScreen({super.key});
  @override
  ConsumerState<TingleFriendsScreen> createState() => _FriendsState();
}
class _FriendsState extends ConsumerState<TingleFriendsScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(tinglePeopleProvider(tab));
    return Scaffold(
      backgroundColor: const Color(0xfff6f4ff),
      appBar: AppBar(
        backgroundColor: Colors.white, centerTitle: true,
        title: const Text('Friends',
          style: TextStyle(fontWeight: FontWeight.w900))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tinglePeopleProvider(tab));
          await ref.read(tinglePeopleProvider(tab).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(child: InkWell(
                    key: ValueKey('friends-tab-$i'),
                    onTap: () => setState(() => tab = i),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: tab == i ? NimzoStyle.primary
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(18)),
                      child: Text(
                        const ['Friends', 'Following', 'Followers'][i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: tab == i ? Colors.white
                            : const Color(0xff897a99))),
                    ),
                  )),
              ]),
            ),
            const SizedBox(height: 16),
            ids.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(25),
                  child: CircularProgressIndicator())),
              error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(tinglePeopleProvider(tab)),
                child: const Text('Unable to load people. Retry')),
              data: (people) => people.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(70),
                    child: Center(child: Text('No people here yet')))
                : Column(children: [
                    for (final person in people)
                      _FriendCard(key: ValueKey('friend-$person'),
                        userId: person, tab: tab),
                  ]),
            ),
          ]),
      ),
    );
  }
}


class _FriendCard extends ConsumerStatefulWidget {
  final String userId;
  final int tab;
  const _FriendCard({
    super.key, required this.userId, required this.tab,
  });

  @override
  ConsumerState<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends ConsumerState<_FriendCard> {
  bool working = false;

  Future<void> toggleFollow(bool following) async {
    if (working) return;
    setState(() => working = true);
    try {
      final service = ref.read(followRepositoryProvider);
      if (following) {
        await service.unfollow(widget.userId);
      } else {
        await service.follow(widget.userId);
      }
      ref.invalidate(isFollowingProvider(widget.userId));
      ref.invalidate(tinglePeopleProvider(1));
      ref.invalidate(tinglePeopleProvider(2));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update follow status. Please retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider(widget.userId));
    final follow = widget.tab == 0
        ? null : ref.watch(isFollowingProvider(widget.userId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(21),
        child: profile.when(
          loading: () => const ListTile(title: Text('Loading profile…')),
          error: (_, __) => ListTile(
            title: const Text('Profile unavailable'),
            trailing: IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(
                profileProvider(widget.userId)),
            ),
          ),
          data: (person) {
            final avatarPath = person.avatarPath;
            final avatar = avatarPath == null ? null
                : ref.watch(sessionSupabaseProvider).client.storage
                    .from('avatars').getPublicUrl(avatarPath);
            final following = follow?.valueOrNull ?? false;
            return ListTile(
              key: ValueKey('friend-profile-${widget.userId}'),
              minTileHeight: 92,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 5),
              onTap: () => context.push('/profile/${widget.userId}'),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xffece0ff),
                backgroundImage: avatar == null
                    ? null : NetworkImage(avatar),
                child: avatar == null
                    ? const Icon(Icons.person_rounded,
                        color: NimzoStyle.primary, size: 30)
                    : null,
              ),
              title: Text(
                person.displayName ?? 'NIMZO user',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff2d233a),
                  fontWeight: FontWeight.w800, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${person.nimzoId}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xff9788a9), fontSize: 12)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xfff2e8ff),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('Lv. ${person.wealthLevel}',
                      style: const TextStyle(
                        color: NimzoStyle.primary,
                        fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              trailing: widget.tab == 0
                  ? IconButton(
                      tooltip: 'Message',
                      onPressed: () =>
                        context.push('/chat/${widget.userId}'),
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        color: NimzoStyle.primary),
                    )
                  : OutlinedButton(
                      onPressed: working || follow?.isLoading == true
                        || follow?.hasError == true
                          ? null
                          : () => toggleFollow(following),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NimzoStyle.primary,
                        side: const BorderSide(
                          color: Color(0xffdfc7f4)),
                        shape: const StadiumBorder()),
                      child: Text(
                        working ? 'Wait…'
                          : follow?.hasError == true ? 'Retry'
                          : following ? 'Following' : 'Follow',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                    ),
            );
          },
        ),
      ),
    );
  }
}
