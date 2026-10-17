import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_repository.dart';

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
                        userId: person),
                  ]),
            ),
          ]),
      ),
    );
  }
}

class _FriendCard extends ConsumerWidget {
  final String userId;
  const _FriendCard({super.key, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider(userId));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffeae4f4))),
      child: user.when(
        loading: () => const ListTile(title: Text('Loading…')),
        error: (_, __) => const ListTile(title: Text('Profile unavailable')),
        data: (person) {
          final avatar = person.avatarPath == null ? null
              : ref.watch(sessionSupabaseProvider).client.storage
                  .from('avatars').getPublicUrl(person.avatarPath!);
          return ListTile(
            minTileHeight: 90,
            onTap: () => context.push('/profile/$userId'),
            leading: CircleAvatar(
              radius: 29,
              backgroundColor: const Color(0xffe9dafa),
              backgroundImage: avatar == null ? null : NetworkImage(avatar),
              child: avatar == null
                ? const Icon(Icons.person, color: NimzoStyle.primary)
                : null),
            title: Text(person.displayName ?? 'NIMZO user',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('ID: ' + person.nimzoId.toString()),
            trailing: IconButton(
              tooltip: 'Message',
              onPressed: () => context.push('/chat/$userId'),
              icon: const Icon(Icons.chat_bubble_rounded,
                color: NimzoStyle.primary)),
          );
        },
      ),
    );
  }
}
