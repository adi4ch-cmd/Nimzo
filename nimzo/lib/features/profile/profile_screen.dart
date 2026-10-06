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
import '../gifts/gift_artwork.dart';
import 'profile_repository.dart';
import 'profile_social_screen.dart';
import 'profile_collections.dart';
import 'profile_couple_section.dart';
import '../gifts/gift_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _visitedId;
  void _openSocial(String id, ProfileSocialList kind) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfileSocialScreen(userId: id, kind: kind),
    ));
  }

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
    final models = ref.watch(profileModelsProvider(id));
    final db = ref.watch(supabaseProvider);

    return Scaffold(
      bottomNavigationBar:
          !isMe ? SafeArea(child: _Actions(targetId: id)) : null,
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
                            left: 0,
                            right: 0,
                            height: 146,
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nimzo ID ${u.nimzoId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (u.gender != null || u.dateOfBirth != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                [
                                  if (u.gender?.isNotEmpty == true) u.gender!,
                                  if (u.dateOfBirth != null)
                                    '${_ageInYears(u.dateOfBirth!)} years',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (u.countryName?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                [
                                  if (u.countryCode?.isNotEmpty == true)
                                    _countryFlag(u.countryCode!),
                                  u.countryName!,
                                ].join(' '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
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
                                    gold: x.startsWith('TOP') ||
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
                          if (u.bio?.trim().isNotEmpty == true) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                u.bio!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          stats.when(
                            data: (s) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Stat('Following', s['following'] ?? 0,
                                    onTap: () => _openSocial(
                                        id, ProfileSocialList.following)),
                                _Stat('Followers', s['followers'] ?? 0,
                                    onTap: () => _openSocial(
                                        id, ProfileSocialList.followers)),
                                _Stat('Visitors', s['visitors'] ?? 0,
                                    onTap: isMe
                                        ? () => _openSocial(
                                            id, ProfileSocialList.visitors)
                                        : null),
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
                          const SizedBox(height: 8),
                          ProfileCoupleSection(userId: id),
                          for (final kind in ProfileCollection.values)
                            ProfileCollectionSection(userId: id, kind: kind),
                          _GiftWallPreview(userId: id),
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

// ISO 3166-1 alpha-2 country codes map to Unicode flag glyphs.
String _countryFlag(String code) {
  final normalized = code.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '';
  return String.fromCharCodes(
    normalized.codeUnits.map((unit) => 0x1F1E6 + unit - 65),
  );
}

int _ageInYears(DateTime birthday) {
  final today = DateTime.now();
  var years = today.year - birthday.year;
  if (today.month < birthday.month ||
      (today.month == birthday.month && today.day < birthday.day)) {
    years--;
  }
  return years < 0 ? 0 : years;
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;
  const _Stat(this.label, this.value, {this.onTap});
  @override
  Widget build(BuildContext c) => Expanded(child: InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text('$value',
                    style: Theme.of(c)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: Theme.of(c).textTheme.bodySmall),
              ],
            )),
      ));
}

/// LOCKED: wealth/charm/active colors approved by product owner.
/// Do not alter ranges, category ordering, or palette without explicit approval.
class _Level extends StatelessWidget {
  final String label;
  final int value;
  const _Level(this.label, this.value);

  static const Map<String, List<Color>> palettes = {
    'Wealth': [
      Color(0xFF79503B),
      Color(0xFF228A4A),
      Color(0xFF2563C8),
      Color(0xFFDB56A4),
      Color(0xFFD33B45),
      Color(0xFFD4A32A),
    ],
    'Charm': [
      Color(0xFFDB56A4),
      Color(0xFFD4A32A),
      Color(0xFF228A4A),
      Color(0xFF2563C8),
      Color(0xFF864DB5),
      Color(0xFFD33B45),
    ],
    'Active': [
      Color(0xFF2563C8),
      Color(0xFFD33B45),
      Color(0xFF864DB5),
      Color(0xFF228A4A),
      Color(0xFFD4A32A),
      Color(0xFFDB56A4),
    ],
  };

  static int tier(int level) {
    if (level <= 20) return 0;
    if (level <= 39) return 1;
    if (level <= 59) return 2;
    if (level <= 79) return 3;
    if (level <= 99) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final palette = palettes[label];
    final color = palette == null ? NimzoColors.primary : palette[tier(value)];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              )),
          Text('Level $value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
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
              style: Theme.of(c)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Actions extends ConsumerStatefulWidget {
  final String targetId;
  const _Actions({required this.targetId});
  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool busy = false;
  Future<void> _change(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      ref.invalidate(isFollowingProvider(widget.targetId));
      ref.invalidate(friendStateProvider(widget.targetId));
      ref.invalidate(profileStatsProvider(widget.targetId));
      final me = ref.read(currentUserIdProvider);
      if (me != null) ref.invalidate(profileStatsProvider(me));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.targetId;
    final following = ref.watch(isFollowingProvider(id));
    final friend = ref.watch(friendStateProvider(id));
    final follow = following.valueOrNull;
    final state = friend.valueOrNull;
    final ready = !busy && ref.watch(currentUserIdProvider) != null;
    return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (following.hasError || friend.hasError)
            TextButton(
                onPressed: () {
                  ref.invalidate(isFollowingProvider(id));
                  ref.invalidate(friendStateProvider(id));
                },
                child: const Text('Retry social actions')),
          Row(children: [
            Expanded(
                child: FilledButton(
              onPressed: !ready || follow == null
                  ? null
                  : () => _change(() => follow
                      ? ref.read(followRepositoryProvider).unfollow(id)
                      : ref.read(followRepositoryProvider).follow(id)),
              child: Text(follow == null
                  ? 'Loading…'
                  : follow
                      ? 'Following'
                      : 'Follow'),
            )),
            const SizedBox(width: 6),
            Expanded(
                child: OutlinedButton(
              onPressed: !ready || state == null || state == FriendState.sent
                  ? null
                  : state == FriendState.friends
                      ? () => context.push('/chat/$id')
                      : () => _change(() => state == FriendState.received
                          ? ref.read(friendRepositoryProvider).accept(id)
                          : ref.read(friendRepositoryProvider).request(id)),
              child: Text(switch (state) {
                null => 'Loading…',
                FriendState.none => 'Add Friend',
                FriendState.sent => 'Requested',
                FriendState.received => 'Accept',
                FriendState.friends => 'Chat',
              }),
            )),
            const SizedBox(width: 6),
            Expanded(
                child: OutlinedButton(
                    onPressed:
                        ready ? () => showProfileGiftSheet(context, id) : null,
                    child: const Text('Gift'))),
          ]),
        ]));
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
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(profileMomentsProvider(userId)).when(
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
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
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

class _GiftWallPreview extends ConsumerWidget {
  final String userId;
  const _GiftWallPreview({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifts = ref.watch(profileGiftsProvider(userId));
    return _SectionPreview(
      title: 'Top 15 Gifts',
      child: gifts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(profileGiftsProvider(userId)),
          child: const Text('Retry loading gifts'),
        ),
        data: (items) {
          if (items.isEmpty) return const Text('No gifts received yet');
          final sorted = [...items]..sort((a, b) {
              final left = (a['quantity'] as num?)?.toInt() ?? 0;
              final right = (b['quantity'] as num?)?.toInt() ?? 0;
              return right.compareTo(left);
            });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final columns = (constraints.maxWidth / 66).floor().clamp(2, 5);
                final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final gift in sorted.take(15)) SizedBox(width: width,
                    child: Column(children: [
                      GiftArtwork(path: gift['image_path'] as String?),
                      Text(gift['name']?.toString() ?? 'Gift', maxLines: 2,
                        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      FittedBox(child: Text('×${gift['quantity'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    ])),
                ]);
              }),
              TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('All received gifts')),
                      body: _ProfileGifts(userId: userId),
                    ),
                  )),
                  child: const Text('View All'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileGifts extends ConsumerWidget {
  final String userId;
  const _ProfileGifts({required this.userId});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(profileGiftsProvider(userId)).when(
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
                          leading:
                              GiftArtwork(path: gift['image_path'] as String?),
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
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(profileAchievementsProvider(userId)).when(
            loading: () => const LoadingView(),
            error: (_, __) => ErrorView(
              message: 'Achievements could not be loaded.',
              onRetry: () =>
                  ref.invalidate(profileAchievementsProvider(userId)),
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
