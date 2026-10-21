import '../store/store_visual_equipment.dart';
import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reference_widgets.dart';
import '../gifts/gift_sheet.dart';
import '../store/store_equipped_frame.dart';
import '../social/social_repositories.dart';
import '../social/friend_button.dart';
import 'profile_repository.dart';
import 'levels_screen.dart';
import 'profile_level_scale.dart';
import 'profile_level_pills.dart';
import 'profile_collections.dart';
import 'profile_setup_screen.dart';
import 'profile_presentation.dart';

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
                    Icon(Icons.directions_car_rounded, size: 16),
                    SizedBox(width: 4),
                    Text('Car'),
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
              EquippedCosmetic(
                  userId: id,
                  category: 'Profile Card',
                  child: SizedBox(
                    height: 170,
                    child: Stack(
                      children: [
                        Container(
                          key: const ValueKey('profile-cover'),
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: NimzoStyle.heroGradient,
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
                            child: EquippedAvatar(
                                userId: id,
                                size: 70,
                                child: NimzoEquippedAvatarFrame(
                                  mediaId: null,
                                  variant: id == me &&
                                          ref.watch(
                                                  nimzoOwnAvatarMediaProvider) ==
                                              null
                                      ? ref.watch(nimzoOwnAvatarFrameProvider)
                                      : null,
                                  avatar: NimzoAvatar(
                                    name: p.displayName ?? p.username ?? 'N',
                                    url: image('avatars', p.avatarPath),
                                    size: 70,
                                    backgroundColor: NimzoStyle.ink,
                                    online: id == me,
                                  ),
                                )),
                          ),
                        ),
                      ],
                    ),
                  )),
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
                          child: EquippedIdentity(
                              userId: id,
                              child: Text(
                                  p.displayName ?? p.username ?? 'Nimzo user',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ))),
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
                    const SizedBox(height: 5),
                    const SizedBox(height: 8),
                    Row(
                      key: const ValueKey('profile-level-badges'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var kind = 0; kind < 3; kind++) ...[
                          if (kind > 0) const SizedBox(width: 6),
                          InkWell(
                            key: ValueKey('profile-level-$kind'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LevelsScreen(
                                  initialKind: kind,
                                  userId: id,
                                ),
                              ),
                            ),
                            child: ProfileLevelPill(
                              kind: kind,
                              level: [
                                p.wealthLevel,
                                p.charmLevel,
                                p.activeLevel,
                              ][kind],
                              compact: true,
                            ),
                          ),
                        ],
                      ],
                    ),
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
                    Wrap(
                      spacing: 12,
                      children: [
                        for (var i = 0; i < 2; i++)
                          TextButton(
                            onPressed: () => setState(() => section = i),
                            child: Text(['Achievements', 'Moments'][i]),
                          ),
                      ],
                    ),
                    if (section == 0)
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
                    if (section == 1)
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
    final amount = total;
    final unit = const ['coins', 'diamonds', 'points'][kind];
    final totalString = amount?.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
    final fraction = amount == null || level < 1
        ? 0.0
        : ProfileLevelScale.fraction(kind, level, amount);
    return Container(
      key: ValueKey('profile-level-compact-$kind'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(
                kind == 0
                    ? Icons.diamond_outlined
                    : kind == 1
                        ? Icons.favorite_border
                        : Icons.bolt_outlined,
                color: accent,
                size: 15),
            const SizedBox(width: 4),
            Expanded(
                child: Text(ProfileLevelScale.labels[kind],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 3),
          Text(level > 0 ? 'Lv $level' : 'Level unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: accent,
                  fontSize: level > 0 ? 16 : 9,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            amount == null ? 'Total unavailable' : '$totalString $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xff64748b)),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 3,
            color: accent,
            backgroundColor: accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
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
  static Color color(int kind, int level) =>
      ProfileLevelScale.color(kind, level);

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
