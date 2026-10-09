import '../vip/phoenix_widgets.dart';
import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reference_widgets.dart';
import '../gifts/gift_sheet.dart';
import '../gifts/yo2_gift_ui.dart';
import '../social/social_repositories.dart';
import '../social/friend_button.dart';
import 'profile_repository.dart';
import 'levels_screen.dart';
import 'profile_collections.dart';
import 'profile_setup_screen.dart';
import 'profile_presentation.dart';
import '../store/store_badge.dart';
import '../gifts/gift_artwork.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int section = 0;
  Widget _actions(BuildContext context, String id, String? me) => me == id
      ? GradientButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfileSetupScreen(edit: true),
            ),
          ),
          child: const Text('Edit profile'),
        )
      : Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffdcfce7),
                  foregroundColor: const Color(0xff16a34a),
                ),
                onPressed: () async {
                  try {
                    final on = await ref.read(isFollowingProvider(id).future);
                    final repo = ref.read(followRepositoryProvider);
                    on ? await repo.unfollow(id) : await repo.follow(id);
                    ref.invalidate(isFollowingProvider(id));
                    ref.invalidate(profileStatsProvider(id));
                    if (me != null) ref.invalidate(profileStatsProvider(me));
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to update follow. Retry.'),
                        ),
                      );
                  }
                },
                child: Text(
                  ref.watch(isFollowingProvider(id)).valueOrNull == true
                      ? 'Following'
                      : 'Follow',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: ReferenceFriendButton(userId: id)),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xfffce7f3),
                  foregroundColor: const Color(0xffdb2777),
                ),
                onPressed: () => showProfileGiftSheet(context, id),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Yo2GiftPanelArt(
                      'ic_user_dialog_gift.webp',
                      width: 18,
                      height: 18,
                      fallback: Icon(Icons.card_giftcard, size: 16),
                    ),
                    SizedBox(width: 4),
                    Text('Gift'),
                  ],
                ),
              ),
            ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider), id = widget.userId ?? me;
    if (id == null)
      return const Scaffold(body: EmptyContent('Please sign in.'));
    return Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: NimzoStyle.line)),
          ),
          child: _actions(context, id, me),
        ),
      ),
      body: AsyncContent(
        value: ref.watch(profileProvider(id)),
        onRetry: () => ref.invalidate(profileProvider(id)),
        builder: (p) {
          final db = ref.watch(supabaseProvider);
          String? image(String bucket, String? path) =>
              path == null ? null : db.storage.from(bucket).getPublicUrl(path);
          final cover = image('covers', p.coverPath);
          return ListView(
            children: [
              SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    Container(
                      key: const ValueKey('profile-cover'),
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff4b5563), Color(0xff111827)],
                        ),
                        image: cover == null
                            ? null
                            : DecorationImage(
                                image: NetworkImage(cover),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SafeArea(
                          bottom: false,
                          child: IconButton(
                            onPressed: () {
                              if (Navigator.of(context).canPop())
                                Navigator.of(context).pop();
                            },
                            icon: const ReferenceIcon(
                              'back',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: SafeArea(
                        bottom: false,
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onSelected: (value) {
                            if (value == 'chat') context.push('/chat/$id');
                            if (value == 'visitors')
                              context.push('/social/visitors/$id');
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'visitors',
                              child: Text('Visitors'),
                            ),
                            if (id != me)
                              const PopupMenuItem(
                                value: 'chat',
                                child: Text('Chat'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 90,
                      left: 16,
                      child: Container(
                        key: const ValueKey('profile-avatar'),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: PhoenixDecoration(
                          userId: id,
                          avatar: true,
                          child: NimzoAvatar(
                            name: p.displayName ?? p.username ?? 'N',
                            url: image('avatars', p.avatarPath),
                            size: 70,
                            backgroundColor: NimzoStyle.ink,
                            online: id == me,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ReferenceIcon(
                          'crown_filled',
                          color: Color(0xfff59e0b),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PhoenixNameplate(
                            userId: id,
                            name: p.displayName ?? p.username ?? 'Nimzo user',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (p.dateOfBirth != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff2563eb),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${p.gender == "Female" ? "♀" : "♂"} ${profileAge(p.dateOfBirth!)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'ID:${p.nimzoId} · ${p.countryName ?? p.countryCode ?? ''}',
                      style: const TextStyle(color: NimzoStyle.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      key: const ValueKey('profile-level-badges'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var kind = 0; kind < 3; kind++) ...[
                          if (kind > 0) const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              key: ValueKey('profile-level-$kind'),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LevelsScreen(
                                    initialKind: kind,
                                    userId: id,
                                  ),
                                ),
                              ),
                              child: ProfileProgressBadge(
                                kind: kind,
                                level: [
                                  p.wealthLevel,
                                  p.charmLevel,
                                  p.activeLevel,
                                ][kind],
                                total: [
                                  p.wealthCoins,
                                  p.charmDiamonds,
                                  p.activePoints,
                                ][kind],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (p.vipLevel > 0 || p.svipLevel > 0)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (p.vipLevel > 0 && p.vipLevel != 6)
                            Chip(label: Text('VIP ${p.vipLevel}')),
                          if (p.svipLevel > 0)
                            Chip(label: Text('SVIP ${p.svipLevel}')),
                        ],
                      ),
                    EquippedRoyalMedal(userId: id),
                    const SizedBox(height: 8),
                    Text(p.bio?.isNotEmpty == true ? p.bio! : 'No bio yet'),
                    AsyncContent(
                      value: ref.watch(profileStatsProvider(id)),
                      onRetry: () => ref.invalidate(profileStatsProvider(id)),
                      builder: (stats) => Wrap(
                        spacing: 10,
                        children: [
                          for (final key in ['following', 'followers'])
                            InkWell(
                              onTap: () => context.push('/social/$key/$id'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${stats[key] ?? 0} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '${key[0].toUpperCase()}${key.substring(1)}',
                                        style: const TextStyle(
                                          color: NimzoStyle.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AsyncContent(
                      value: ref.watch(profileTagsProvider(id)),
                      onRetry: () => ref.invalidate(profileTagsProvider(id)),
                      builder: (tags) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < tags.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: [
                                  const Color(0xffdcfce7),
                                  const Color(0xffede9fe),
                                  const Color(0xfffce7f3),
                                  const Color(0xffe0f2fe),
                                ][i % 4],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tags[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: [
                                    const Color(0xff16a34a),
                                    const Color(0xff7c3aed),
                                    const Color(0xffdb2777),
                                    const Color(0xff0284c7),
                                  ][i % 4],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text(
                      'CP relationship',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    AsyncContent(
                      value: ref.watch(profileCoupleProvider(id)),
                      onRetry: () => ref.invalidate(profileCoupleProvider(id)),
                      builder: (cp) {
                        if (cp == null)
                          return CouplePanel(
                            name: p.displayName ?? 'N',
                            avatarUrl: image('avatars', p.avatarPath),
                            onAdd: me == id ? () => context.push('/cp') : null,
                          );
                        final partner =
                            cp['user_a'] == id ? cp['user_b'] : cp['user_a'];
                        return AsyncContent(
                          value: ref.watch(profileProvider(partner)),
                          onRetry: () =>
                              ref.invalidate(profileProvider(partner)),
                          builder: (other) => CouplePanel(
                            name: p.displayName ?? 'N',
                            avatarUrl: image('avatars', p.avatarPath),
                            partnerAvatarUrl: image(
                              'avatars',
                              other.avatarPath,
                            ),
                            partner: other.displayName ??
                                other.username ??
                                'Nimzo user',
                            days: DateTime.tryParse(
                                      cp['created_at']?.toString() ?? '',
                                    ) ==
                                    null
                                ? 0
                                : DateTime.now()
                                    .difference(
                                      DateTime.parse(
                                        cp['created_at'].toString(),
                                      ),
                                    )
                                    .inDays,
                          ),
                        );
                      },
                    ),
                    if (me == id)
                      TextButton(
                        onPressed: () => context.push('/cp'),
                        child: const Text('CP invitations'),
                      ),
                    for (final kind in ProfileCollection.values) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              {
                                'medal': 'Medal Wall',
                                'frame': 'Frame',
                                'car': 'Car',
                              }[kind.name]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showReferenceSheet(
                              context,
                              Consumer(
                                builder: (context, ref, _) => Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: AsyncContent(
                                    value: ref.watch(
                                      profileCollectionProvider((id, kind)),
                                    ),
                                    onRetry: () => ref.invalidate(
                                      profileCollectionProvider((id, kind)),
                                    ),
                                    builder: (items) => items.isEmpty
                                        ? const EmptyContent('No items yet')
                                        : SingleChildScrollView(
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                for (final item in items)
                                                  CollectibleArtwork(
                                                    item: item,
                                                  ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                color: NimzoStyle.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AsyncContent(
                        value: ref.watch(profileCollectionProvider((id, kind))),
                        onRetry: () => ref.invalidate(
                          profileCollectionProvider((id, kind)),
                        ),
                        builder: (items) => items.isEmpty
                            ? const EmptyContent('No items yet')
                            : Wrap(
                                children: [
                                  for (final item in items)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: CollectibleArtwork(item: item),
                                    ),
                                ],
                              ),
                      ),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gifts (Top 15)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('all-received-gifts'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _AllGifts(id: id),
                            ),
                          ),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (var i = 0; i < 3; i++)
                          TextButton(
                            onPressed: () => setState(() => section = i),
                            child: Text(
                              ['Gifts', 'Achievements', 'Moments'][i],
                            ),
                          ),
                      ],
                    ),
                    if (section == 0) GiftList(id: id, limit: 15),
                    if (section == 1)
                      AsyncContent(
                        value: ref.watch(profileAchievementsProvider(id)),
                        onRetry: () =>
                            ref.invalidate(profileAchievementsProvider(id)),
                        builder: (a) => a.isEmpty
                            ? const EmptyContent('No achievements yet')
                            : Column(
                                children: [
                                  for (final name in a)
                                    ListTile(title: Text(name)),
                                ],
                              ),
                      ),
                    if (section == 2)
                      AsyncContent(
                        value: ref.watch(profileMomentsProvider(id)),
                        onRetry: () =>
                            ref.invalidate(profileMomentsProvider(id)),
                        builder: (a) => a.isEmpty
                            ? const EmptyContent('No Moments yet')
                            : Column(
                                children: [
                                  for (final post in a)
                                    ListTile(
                                      title: Text(post.text ?? ''),
                                      onTap: () =>
                                          context.push('/moments/${post.id}'),
                                    ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GiftList extends ConsumerWidget {
  final String id;
  final int? limit;
  const GiftList({super.key, required this.id, this.limit});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(profileGiftsProvider(id))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => DataFailure(
          message: 'Gifts could not be loaded.',
          onRetry: () => ref.invalidate(profileGiftsProvider(id)),
        ),
        data: (g) => g.isEmpty
            ? const EmptyContent('No gifts received yet')
            : SizedBox(
                height: 96 * MediaQuery.textScalerOf(context).scale(1),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final item in g.take(limit ?? g.length))
                      SizedBox(
                        width: 64,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 46,
                              height: 44,
                              child: GiftArtwork(
                                name: item['name'].toString(),
                                assetPath: item['asset_path']?.toString(),
                              ),
                            ),
                            Text(
                              item['name'].toString(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, height: 1.2),
                            ),
                            Text(
                              '× ${item['quantity']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      );
}

class _AllGifts extends StatelessWidget {
  final String id;
  const _AllGifts({required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('All received gifts')),
        body: SingleChildScrollView(child: GiftList(id: id)),
      );
}

class ProfileProgressBadge extends StatelessWidget {
  final int kind, level;
  final int? total;
  const ProfileProgressBadge({
    super.key,
    required this.kind,
    required this.level,
    this.total,
  });

  static Color color(int kind, int level) => LevelBadge.color(kind, level);

  @override
  Widget build(BuildContext context) {
    final accent = color(kind, level);
    final label = const ['Wealth', 'Charm', 'Active'][kind];
    final unit = const ['coins', 'diamonds', 'points'][kind];
    final amount = total?.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, .24)!],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white, fontSize: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReferenceIcon(
                  kind == 0 ? 'crown' : 'star',
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              amount == null ? 'Total unavailable' : '$amount $unit',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              level > 0 ? 'Lv $level' : 'Level unavailable',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelBadge extends StatelessWidget {
  final int kind, level;
  final bool showLabel;
  const LevelBadge({
    super.key,
    required this.kind,
    required this.level,
    this.showLabel = false,
  });
  static Color color(int kind, int level) {
    if (kind == 1) return const Color(0xff2563eb);
    if (kind == 2) return const Color(0xffdc2626);
    if (level < 1 || level > 120) return const Color(0xff6b7280);
    if (level <= 20) return const Color(0xffa16207);
    if (level <= 39) return const Color(0xff16a34a);
    if (level <= 59) return const Color(0xff2563eb);
    if (level <= 79) return const Color(0xffdb2777);
    if (level <= 99) return const Color(0xffdc2626);
    return const Color(0xffd4a017);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: showLabel ? 5 : 10, vertical: 4),
        decoration: BoxDecoration(
          color: color(kind, level),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReferenceIcon(
              kind == 0 ? 'crown' : 'star',
              size: showLabel ? 12 : 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                showLabel
                    ? '${const [
                        'Wealth',
                        'Charm',
                        'Active'
                      ][kind]} ${level > 0 ? level : '—'}'
                    : (level > 0 ? '$level' : '—'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: showLabel ? 9 : 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
