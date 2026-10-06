import '../auth/presentation/auth_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_avatar.dart';
import '../../core/widgets/nimzo_badge.dart';
import '../../core/widgets/nimzo_icon.dart';
import '../social/social_repositories.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _visitedId;
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final id = widget.userId ?? me;
    if (id == null) return const LoadingView();
    final isMe = id == me;
    if (!isMe && _visitedId != id) {
      _visitedId = id;
      Future.microtask(() {
        if (mounted) ref.read(profileRepositoryProvider).recordVisit(id);
      });
    }
    final p = ref.watch(profileProvider(id));
    final stats = ref.watch(profileStatsProvider(id));
    final tags = ref.watch(profileTagsProvider(id));
    final couple = ref.watch(profileCoupleProvider(id));
    final models = ref.watch(profileModelsProvider(id));
    final db = ref.watch(supabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Profile' : ''),
        actions: [
          if (isMe)
            IconButton(
              icon: const NimzoIcon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF2E9B73),
              ),
              onPressed: () => context.push('/wallet'),
            ),
          if (isMe)
            IconButton(
              icon: const NimzoIcon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFE0A72E),
              ),
              onPressed: () => context.push('/vip'),
            ),
          if (isMe)
            IconButton(
              icon: const NimzoIcon(
                Icons.settings_rounded,
                color: Color(0xFF64748B),
              ),
              onPressed: () => context.push('/profile-setup'),
            ),
          if (isMe)
            IconButton(
              icon: const NimzoIcon(
                Icons.logout_rounded,
                color: Color(0xFFD85C5C),
              ),
              tooltip: 'Sign out',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'Your account and conversations will be here when you return.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(authControllerProvider.notifier).signOut();
                  final result = ref.read(authControllerProvider);
                  if (result.hasError && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('${result.error}')));
                  }
                }
              },
            ),
        ],
      ),
      body: p.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(profileProvider(id)),
        ),
        data: (u) => DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(
                      height: 190,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 16,
                            right: 16,
                            height: 146,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _ProfileCover(
                                url: storageUrl(db, 'covers', u.coverPath),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: NimzoColors.background,
                                ),
                                child: NimzoAvatar(
                                  radius: 44,
                                  url: storageUrl(db, 'avatars', u.avatarPath),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            (u.displayName?.trim().isNotEmpty == true)
                                ? u.displayName!
                                : 'Nimzo User',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nimzo ID ${u.nimzoId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (u.countryName != null)
                            Text(
                              [u.countryName, u.language]
                                  .whereType<String>()
                                  .where((v) => v.isNotEmpty)
                                  .join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 10),
                          tags.maybeWhen(
                            data: (t) => Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final x in t)
                                  NimzoBadge(
                                    x,
                                    gold:
                                        x.startsWith('TOP') ||
                                        x.contains('VIP'),
                                  ),
                              ],
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              if (u.wealthLevel > 0)
                                _Level('Wealth', u.wealthLevel),
                              if (u.charmLevel > 0)
                                _Level('Charm', u.charmLevel),
                              if (u.activeLevel > 0)
                                _Level('Active', u.activeLevel),
                              if (u.vipLevel > 0) _Level('VIP', u.vipLevel),
                              if (u.svipLevel > 0) _Level('SVIP', u.svipLevel),
                            ],
                          ),
                          const SizedBox(height: 14),
                          stats.when(
                            data: (s) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Stat('Following', s['following'] ?? 0),
                                _Stat('Followers', s['followers'] ?? 0),
                                _Stat('Visitors', s['visitors'] ?? 0),
                              ],
                            ),
                            loading: () => const SizedBox(
                              height: 42,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            error: (_, __) => Text(
                              'Stats unavailable',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          if (!isMe) _Actions(targetId: id),
                          const SizedBox(height: 8),
                          couple.maybeWhen(
                            data: (c) => _SectionPreview(
                              title: 'CP / Couple',
                              child: c == null
                                  ? const Text('No couple linked')
                                  : Text(
                                      c['display_name']?.toString() ??
                                          'Linked couple',
                                    ),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          models.maybeWhen(
                            data: (m) => _SectionPreview(
                              title: 'Models',
                              child: m.isEmpty
                                  ? const Text('No model profile yet')
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final x in m)
                                          Text(
                                            x['title']?.toString() ?? 'Model',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: 'About'),
                        Tab(text: 'Moments'),
                        Tab(text: 'Gifts'),
                        Tab(text: 'Achievements'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    u.bio?.isNotEmpty == true ? u.bio! : 'No bio yet.',
                  ),
                ),
                _ProfileMoments(userId: id),
                _ProfileGifts(userId: id),
                _ProfileAchievements(userId: id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext c) => Column(
    children: [
      Text(
        '$value',
        style: Theme.of(c).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(label, style: Theme.of(c).textTheme.bodySmall),
    ],
  );
}

class _Level extends StatelessWidget {
  final String label;
  final int value;
  const _Level(this.label, this.value);
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: NimzoColors.primaryFaint,
    ),
    child: Column(
      children: [
        Text(
          'Level $value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(label, style: Theme.of(c).textTheme.bodySmall),
      ],
    ),
  );
}

class _SectionPreview extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionPreview({required this.title, required this.child});
  @override
  Widget build(BuildContext c) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(c).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(c).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Actions extends ConsumerWidget {
  final String targetId;
  const _Actions({required this.targetId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follow =
        ref.watch(isFollowingProvider(targetId)).valueOrNull ?? false;
    final fs =
        ref.watch(friendStateProvider(targetId)).valueOrNull ??
        FriendState.none;
    final fr = ref.read(friendRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: () async {
              final r = ref.read(followRepositoryProvider);
              follow ? await r.unfollow(targetId) : await r.follow(targetId);
              ref.invalidate(isFollowingProvider(targetId));
            },
            child: Text(follow ? 'Following' : 'Follow'),
          ),
          OutlinedButton(
            onPressed: () => context.push('/chat/$targetId'),
            child: const Text('Message'),
          ),
          OutlinedButton(
            onPressed: switch (fs) {
              FriendState.none => () async {
                await fr.request(targetId);
                ref.invalidate(friendStateProvider(targetId));
              },
              FriendState.received => () async {
                await fr.accept(targetId);
                ref.invalidate(friendStateProvider(targetId));
              },
              _ => null,
            },
            child: Text(switch (fs) {
              FriendState.none => 'Add Friend',
              FriendState.sent => 'Request Sent',
              FriendState.received => 'Accept',
              FriendState.friends => 'Friends',
            }),
          ),
        ],
      ),
    );
  }
}

class _ProfileCover extends StatelessWidget {
  final String? url;
  const _ProfileCover({this.url});
  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(color: NimzoColors.primaryLight);
    return url == null
        ? fallback
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );
  }
}

class _ProfileMoments extends ConsumerWidget {
  final String userId;
  const _ProfileMoments({required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(profileMomentsProvider(userId))
      .when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Moments could not be loaded.',
          onRetry: () => ref.invalidate(profileMomentsProvider(userId)),
        ),
        data: (moments) => moments.isEmpty
            ? const EmptyView(
                title: 'No moments yet',
                hint: 'Shared moments appear here.',
                icon: Icons.photo_library_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: moments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = moments[i];
                  return _SectionPreview(
                    title: timeAgo(m.createdAt),
                    child: InkWell(
                      onTap: () => context.push('/moments/${m.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.imagePath != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                storageUrl(
                                  ref.watch(supabaseProvider),
                                  'moment-images',
                                  m.imagePath,
                                )!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  height: 72,
                                  child: Center(
                                    child: NimzoIcon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (m.text?.isNotEmpty == true) Text(m.text!),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
}

class _ProfileGifts extends ConsumerWidget {
  final String userId;
  const _ProfileGifts({required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(profileGiftsProvider(userId))
      .when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Gifts could not be loaded.',
          onRetry: () => ref.invalidate(profileGiftsProvider(userId)),
        ),
        data: (gifts) => gifts.isEmpty
            ? const EmptyView(
                title: 'No gifts received yet',
                hint: 'Gifts from your community appear here.',
                icon: Icons.card_giftcard_rounded,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: gifts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final gift = gifts[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: NimzoColors.surface,
                      border: Border.all(color: NimzoColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const NimzoIcon(
                        Icons.card_giftcard_rounded,
                        color: NimzoColors.primary,
                      ),
                      title: Text(gift['name']?.toString() ?? 'Gift'),
                      trailing: Text(
                        '× ${gift['quantity'] ?? 0}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  );
                },
              ),
      );
}

class _ProfileAchievements extends ConsumerWidget {
  final String userId;
  const _ProfileAchievements({required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(profileAchievementsProvider(userId))
      .when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Achievements could not be loaded.',
          onRetry: () => ref.invalidate(profileAchievementsProvider(userId)),
        ),
        data: (achievements) => achievements.isEmpty
            ? const EmptyView(
                title: 'No achievements yet',
                hint: 'Your earned achievements appear here.',
                icon: Icons.emoji_events_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final achievement in achievements)
                    _SectionPreview(
                      title: achievement,
                      child: const NimzoIcon(
                        Icons.emoji_events_outlined,
                        color: NimzoColors.primary,
                      ),
                    ),
                ],
              ),
      );
}
