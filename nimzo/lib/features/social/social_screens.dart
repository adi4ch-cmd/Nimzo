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
          args.$2)
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
        row['visitor_id'].toString():
            DateTime.parse(row['visited_at'].toString())
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
                onRetry: () =>
                    ref.invalidate(socialListProvider((kind, userId))),
                builder: (rows) => rows.isEmpty
                    ? const EmptyContent('No users yet')
                    : Column(children: [
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
                                          .getPublicUrl(p.avatarPath!)),
                              title: Text(
                                  p.displayName ?? p.username ?? 'Nimzo user'),
                              subtitle: Text(
                                  'ID:${p.nimzoId}${kind == 'visitors' && userId == ref.watch(currentUserIdProvider) && ref.watch(visitorTimesProvider).valueOrNull?[p.id] != null ? ' · ${visitLabel(ref.watch(visitorTimesProvider).valueOrNull![p.id]!)}' : ''}'),
                              trailing: ReferenceFollowButton(userId: p.id),
                              onTap: () => context.push('/profile/${p.id}'))
                      ]))
          ]));
}

final coupleRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => await ref
        .watch(sessionSupabaseProvider)
        .client
        .from('couple_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50));

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

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      ref.invalidate(coupleRequestsProvider);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('CP request could not be completed. Retry.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider),
        db = ref.watch(supabaseProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Choose your CP')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: query,
              decoration: const InputDecoration(labelText: 'Nimzo ID or name'),
              onSubmitted: (_) => run(() async {
                    final rows = await ref
                        .read(profileRepositoryProvider)
                        .search(query.text);
                    if (mounted)
                      setState(() =>
                          candidates = rows.where((p) => p.id != me).toList());
                  })),
          for (final p in candidates)
            ListTile(
                title: Text(p.displayName ?? p.username ?? 'Nimzo user'),
                subtitle: Text('ID:${p.nimzoId}'),
                trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              await db.from('couple_requests').insert(
                                  {'requester_id': me, 'addressee_id': p.id});
                              if (mounted) setState(() => candidates = []);
                            }),
                    child: const Text('Invite'))),
          AsyncContent(
              value: ref.watch(coupleRequestsProvider),
              onRetry: () => ref.invalidate(coupleRequestsProvider),
              builder: (rows) => rows.isEmpty
                  ? const EmptyContent('No pending invitations')
                  : Column(children: [
                      for (final r in rows)
                        Consumer(builder: (context, ref, _) {
                          final other = r['requester_id'] == me
                                  ? r['addressee_id']
                                  : r['requester_id'],
                              p = ref
                                  .watch(profileProvider(other as String))
                                  .valueOrNull;
                          return ReferenceCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(p?.displayName ?? 'Nimzo user'),
                                if (r['addressee_id'] == me)
                                  Wrap(children: [
                                    for (final accept in [true, false])
                                      TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => run(() async {
                                                    await db.rpc(
                                                        'respond_couple_request',
                                                        params: {
                                                          'p_request': r['id'],
                                                          'p_accept': accept
                                                        });
                                                    if (me != null)
                                                      ref.invalidate(
                                                          profileCoupleProvider(
                                                              me));
                                                  }),
                                          child: Text(
                                              accept ? 'Accept' : 'Decline'))
                                  ])
                                else
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => run(() async {
                                                await db
                                                    .from('couple_requests')
                                                    .delete()
                                                    .eq('id', r['id']);
                                              }),
                                      child: const Text('Cancel invitation'))
                              ]));
                        })
                    ])),
        ]));
  }
}
