import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_avatar.dart';
import '../../core/widgets/nimzo_badge.dart';
import '../social/social_repositories.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    final id = userId ?? me;
    if (id == null) return const LoadingView();
    final isMe = id == me;
    if (!isMe) Future.microtask(() => ref.read(profileRepositoryProvider).recordVisit(id));
    final p = ref.watch(profileProvider(id));
    final stats = ref.watch(profileStatsProvider(id));
    final tags = ref.watch(profileTagsProvider(id));
    final couple = ref.watch(profileCoupleProvider(id));
    final models = ref.watch(profileModelsProvider(id));
    final db = ref.watch(supabaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isMe ? 'Profile' : ''), actions: [
        if (isMe) IconButton(icon: const Icon(Icons.account_balance_wallet_outlined), onPressed: () => context.push('/wallet')),
        if (isMe) IconButton(icon: const Icon(Icons.workspace_premium_outlined), onPressed: () => context.push('/vip')),
        if (isMe) IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/profile-setup')),
        if (isMe) IconButton(
          icon: const Icon(Icons.logout_outlined),
          tooltip: 'Sign out',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text('Your Nimzo account and data will remain محفوظ.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(supabaseProvider).auth.signOut();
            }
          },
        ),
      ]),
      body: p.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(profileProvider(id))),
        data: (u) => DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [SliverToBoxAdapter(child: Column(children: [
              Container(height: 110, width: double.infinity, color: Theme.of(context).colorScheme.surfaceContainerHighest),
              Transform.translate(offset: const Offset(0, -38), child: Column(children: [
                NimzoAvatar(radius: 46, url: storageUrl(db, 'avatars', u.avatarPath)),
                const SizedBox(height: 8),
                Text((u.displayName?.trim().isNotEmpty == true) ? u.displayName! : 'Nimzo User', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Nimzo ID ${u.nimzoId}', style: Theme.of(context).textTheme.bodySmall),
                if (u.countryName != null) Text('${u.countryName} · ${u.language ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                tags.maybeWhen(data: (t) => Wrap(spacing: 6, runSpacing: 6, children: [for (final x in t) NimzoBadge(x, gold: x.startsWith('TOP') || x.contains('VIP'))]), orElse: () => const SizedBox.shrink()),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _Level('Wealth', u.wealthLevel), _Level('Charm', u.charmLevel), _Level('Active', u.activeLevel),
                ]),
                const SizedBox(height: 14),
                stats.maybeWhen(data: (s) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _Stat('Following', s['following'] ?? 0), _Stat('Followers', s['followers'] ?? 0), _Stat('Visitors', s['visitors'] ?? 0),
                ]), orElse: () => const SizedBox(height: 42)),
                if (!isMe) _Actions(targetId: id),
                const SizedBox(height: 8),
                couple.maybeWhen(data: (c) => _SectionPreview(title: 'CP / Couple', child: c == null ? const Text('No couple linked') : const Text('Couple linked')), orElse: () => const SizedBox.shrink()),
                models.maybeWhen(data: (m) => _SectionPreview(title: 'Models', child: m.isEmpty ? const Text('No model profile yet') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final x in m) Text(x['title']?.toString() ?? 'Model', style: const TextStyle(fontWeight: FontWeight.w600))])), orElse: () => const SizedBox.shrink()),
                const TabBar(tabs: [Tab(text: 'About'), Tab(text: 'Moments'), Tab(text: 'Gifts'), Tab(text: 'Achievements')]),
              ])),
            ]))],
            body: TabBarView(children: [
              Padding(padding: const EdgeInsets.all(20), child: Text(u.bio?.isNotEmpty == true ? u.bio! : 'No bio yet.')),
              const Center(child: Text('No moments yet')),
              const Center(child: Text('No gifts yet')),
              const Center(child: Text('No achievements yet')),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget { final String label; final int value; const _Stat(this.label, this.value); @override Widget build(BuildContext c) => Column(children: [Text('$value', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), Text(label, style: Theme.of(c).textTheme.bodySmall)]); }
class _Level extends StatelessWidget { final String label; final int value; const _Level(this.label, this.value); @override Widget build(BuildContext c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(c).colorScheme.surfaceContainerHighest), child: Column(children: [Text('Lv $value', style: const TextStyle(fontWeight: FontWeight.w700)), Text(label, style: Theme.of(c).textTheme.bodySmall)])); }
class _SectionPreview extends StatelessWidget { final String title; final Widget child; const _SectionPreview({required this.title, required this.child}); @override Widget build(BuildContext c) => Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(16, 6, 16, 6), padding: const EdgeInsets.all(14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(c).dividerColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(c).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), child])); }

class _Actions extends ConsumerWidget {
  final String targetId;
  const _Actions({required this.targetId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follow = ref.watch(isFollowingProvider(targetId)).valueOrNull ?? false;
    final fs = ref.watch(friendStateProvider(targetId)).valueOrNull ?? FriendState.none;
    final fr = ref.read(friendRepositoryProvider);
    return Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, children: [
      FilledButton(onPressed: () async { final r = ref.read(followRepositoryProvider); follow ? await r.unfollow(targetId) : await r.follow(targetId); ref.invalidate(isFollowingProvider(targetId)); }, child: Text(follow ? 'Following' : 'Follow')),
      OutlinedButton(onPressed: () => context.push('/chat/$targetId'), child: const Text('Message')),
      OutlinedButton(onPressed: switch (fs) { FriendState.none => () async { await fr.request(targetId); ref.invalidate(friendStateProvider(targetId)); }, FriendState.received => () async { await fr.accept(targetId); ref.invalidate(friendStateProvider(targetId)); }, _ => null }, child: Text(switch (fs) { FriendState.none => 'Add Friend', FriendState.sent => 'Request Sent', FriendState.received => 'Accept', FriendState.friends => 'Friends' })),
    ]));
  }
}
