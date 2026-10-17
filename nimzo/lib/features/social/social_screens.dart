import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile.dart';
import '../profile/profile_repository.dart';
import 'follow_button.dart';
import 'social_repositories.dart';

final socialListProvider =
    FutureProvider.family<List<Profile>, (String, String)>((ref, args) async {
  final db = ref.watch(sessionSupabaseProvider).client;
  final visitors = args.$1 == 'visitors';
  final following = args.$1 == 'following';
  final column = visitors
      ? 'visitor_id'
      : following
          ? 'followee_id'
          : 'follower_id';
  final rows = await db
      .from(visitors ? 'visitors' : 'follows')
      .select(column)
      .eq(
        visitors
            ? 'profile_id'
            : following
                ? 'follower_id'
                : 'followee_id',
        args.$2,
      )
      .limit(50);
  final ids = rows.map((r) => r[column] as String).toList();
  if (ids.isEmpty) return [];
  return (await db.from('profiles').select().inFilter('id', ids))
      .map(Profile.fromJson)
      .toList();
});

final visitorTimesProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final rows = await ref.watch(visitorRepositoryProvider).mine();
  return {
    for (final row in rows)
      if (DateTime.tryParse(row['visited_at']?.toString() ?? '') != null)
        row['visitor_id'].toString(): DateTime.parse(
          row['visited_at'].toString(),
        ),
  };
});
String visitLabel(DateTime time) {
  final now = DateTime.now();
  final t = time.toLocal();
  return now.year == t.year && now.month == t.month && now.day == t.day
      ? 'visited today'
      : 'visited ${t.day}/${t.month}/${t.year}';
}

class SocialListScreen extends ConsumerWidget {
  final String kind, userId;
  const SocialListScreen({super.key, required this.kind, required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar:
            AppBar(title: Text('${kind[0].toUpperCase()}${kind.substring(1)}')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            AsyncContent(
              value: ref.watch(socialListProvider((kind, userId))),
              onRetry: () => ref.invalidate(socialListProvider((kind, userId))),
              builder: (rows) => rows.isEmpty
                  ? const EmptyContent('No users yet')
                  : Column(
                      children: [
                        for (final p in rows)
                          ListTile(
                            leading: NimzoAvatar(
                              name: p.displayName ?? 'N',
                              url: p.avatarPath == null
                                  ? null
                                  : ref
                                      .watch(supabaseProvider)
                                      .storage
                                      .from('avatars')
                                      .getPublicUrl(p.avatarPath!),
                            ),
                            title: Text(
                              p.displayName ?? p.username ?? 'Nimzo user',
                            ),
                            subtitle: Text(
                              'ID:${p.nimzoId}${kind == 'visitors' && userId == ref.watch(currentUserIdProvider) && ref.watch(visitorTimesProvider).valueOrNull?[p.id] != null ? ' · ${visitLabel(ref.watch(visitorTimesProvider).valueOrNull![p.id]!)}' : ''}',
                            ),
                            trailing: ReferenceFollowButton(userId: p.id),
                            onTap: () => context.push('/profile/${p.id}'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
}

final coupleRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => await ref
      .watch(sessionSupabaseProvider)
      .client
      .from('couple_requests')
      .select()
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .limit(50),
);

class CoupleRequestsScreen extends ConsumerStatefulWidget {
  const CoupleRequestsScreen({super.key});
  @override
  ConsumerState<CoupleRequestsScreen> createState() => _CPState();
}

class _CPState extends ConsumerState<CoupleRequestsScreen> {
  final query = TextEditingController();
  List<Profile> candidates = [];
  bool busy = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      ref.invalidate(coupleRequestsProvider);
      final me = ref.read(currentUserIdProvider);
      if (me != null) ref.invalidate(profileCoupleProvider(me));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'CP request could not be completed. Retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> search() => run(() async {
    if (query.text.trim().isEmpty) return;
    final me = ref.read(currentUserIdProvider);
    final profiles = await ref.read(profileRepositoryProvider)
        .search(query.text.trim());
    if (mounted) setState(() =>
      candidates = profiles.where((p) => p.id != me).toList());
  });

  Future<void> invite(Profile user) => run(() async {
    final me = ref.read(currentUserIdProvider);
    if (me == null) throw StateError('Sign-in required');
    await ref.read(sessionSupabaseProvider).client
      .from('couple_requests').insert({
        'requester_id': me,
        'addressee_id': user.id,
      });
    if (mounted) setState(() => candidates = []);
  });

  Future<void> respond(Map<String, dynamic> request, bool accept) =>
    run(() async {
      final me = ref.read(currentUserIdProvider);
      if (request['addressee_id'] != me) {
        throw StateError('Only the receiver can respond');
      }
      await ref.read(sessionSupabaseProvider).client.rpc(
        'respond_couple_request',
        params: {
          'p_request': request['id'],
          'p_accept': accept,
        },
      );
    });

  Future<void> cancel(Map<String, dynamic> request) =>
    run(() async {
      final me = ref.read(currentUserIdProvider);
      if (request['requester_id'] != me) {
        throw StateError('Only the sender can cancel');
      }
      await ref.read(sessionSupabaseProvider).client
        .from('couple_requests').delete()
        .eq('id', request['id'])
        .eq('requester_id', me!);
    });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final couple = me == null ? null
      : ref.watch(profileCoupleProvider(me));
    return Scaffold(
      backgroundColor: const Color(0xfff7f5ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text('CP Space', style: TextStyle(
          color: Color(0xff342444),
          fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coupleRequestsProvider);
          if (me != null) ref.invalidate(profileCoupleProvider(me));
          await ref.read(coupleRequestsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(17, 17, 17, 35),
          children: [
            Container(
              height: 252,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffae54f0), Color(0xffec77c2),
                    Color(0xffffb3c8),
                  ]),
                borderRadius: BorderRadius.circular(27),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -51, top: -75,
                    child: CircleAvatar(
                      radius: 123,
                      backgroundColor:
                        Colors.white.withValues(alpha: .09)),
                  ),
                  Positioned(
                    right: -26, bottom: -74,
                    child: CircleAvatar(
                      radius: 111,
                      backgroundColor:
                        Colors.white.withValues(alpha: .09)),
                  ),
                  const Positioned(
                    top: 25, left: 0, right: 0,
                    child: Text('SWEET CONNECTION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffffecf9),
                        letterSpacing: 2,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _CPAvatar(icon: Icons.person_outline_rounded),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 13),
                          child: Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 49)),
                        const _CPAvatar(icon: Icons.favorite_border),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 15, right: 15, bottom: 24,
                    child: Text(
                      couple?.when(
                        data: (p) => p == null
                          ? 'Find your special NIMZO partner'
                          : 'Your CP connection is active',
                        loading: () => 'Loading CP…',
                        error: (_, __) => 'CP status unavailable',
                      ) ?? 'Choose your CP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Find your CP', style: TextStyle(
              color: Color(0xff322340),
              fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: const Color(0xffece8f5)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 5, 4, 5),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: query,
                  enabled: !busy,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search NIMZO ID or name',
                    hintStyle: TextStyle(color: Color(0xffa29ab4)),
                    prefixIcon: Icon(Icons.search,
                      color: Color(0xff8f5ace)),
                  ),
                  onSubmitted: (_) => search(),
                )),
                FilledButton(
                  onPressed: busy ? null : search,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffa145ee),
                    shape: const StadiumBorder()),
                  child: Text(busy ? 'Wait…' : 'Find'),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            for (final candidate in candidates)
              _CPUserCard(
                user: candidate,
                onTap: () => context.push('/profile/${candidate.id}'),
                action: OutlinedButton(
                  onPressed: busy ? null : () => invite(candidate),
                  child: const Text('Invite'),
                ),
              ),
            const SizedBox(height: 23),
            const Text('CP Invitations', style: TextStyle(
              color: Color(0xff322340), fontSize: 19,
              fontWeight: FontWeight.w900)),
            const SizedBox(height: 11),
            AsyncContent(
              value: ref.watch(coupleRequestsProvider),
              onRetry: () => ref.invalidate(coupleRequestsProvider),
              builder: (rows) => rows.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30, horizontal: 17),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(19)),
                      child: const Text('No pending invitations',
                        style: TextStyle(
                          color: Color(0xff8e839e),
                          fontWeight: FontWeight.w600)),
                    )
                  : Column(
                      children: [
                        for (final request in rows)
                          Consumer(builder: (context, ref, _) {
                            final sender = request['requester_id'] == me;
                            final otherId = sender
                              ? request['addressee_id'].toString()
                              : request['requester_id'].toString();
                            final profile = ref.watch(
                              profileProvider(otherId)).valueOrNull;
                            return _CPUserCard(
                              user: profile,
                              fallbackId: otherId,
                              onTap: () => context.push('/profile/$otherId'),
                              action: sender
                                ? TextButton(
                                    onPressed: busy ? null
                                      : () => cancel(request),
                                    child: const Text('Cancel'))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: busy ? null
                                          : () => respond(request, false),
                                        child: const Text('Decline')),
                                      FilledButton(
                                        onPressed: busy ? null
                                          : () => respond(request, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                            const Color(0xffa145ee)),
                                        child: const Text('Accept')),
                                    ],
                                  ),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CPAvatar extends StatelessWidget {
  final IconData icon;
  const _CPAvatar({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    height: 77, width: 77,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xfff7e8ff),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [
        BoxShadow(color: Color(0x257a327c), blurRadius: 12),
      ],
    ),
    child: Icon(icon, size: 37, color: const Color(0xffb044a9)),
  );
}

class _CPUserCard extends StatelessWidget {
  final Profile? user;
  final String? fallbackId;
  final Widget action;
  final VoidCallback onTap;
  const _CPUserCard({
    required this.user,
    required this.action,
    required this.onTap,
    this.fallbackId,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffeeeaf6))),
    child: ListTile(
      minTileHeight: 79,
      onTap: onTap,
      leading: const CircleAvatar(
        radius: 25,
        backgroundColor: Color(0xfff0e0ff),
        child: Icon(Icons.person, color: Color(0xffa048d1))),
      title: Text(user?.displayName ?? user?.username ?? 'NIMZO user',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('ID: ${user?.nimzoId ?? fallbackId ?? '…'}',
        style: const TextStyle(color: Color(0xff9786a7))),
      trailing: action,
    ),
  );
}
