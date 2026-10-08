import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reference_widgets.dart';
import '../gifts/gift_sheet.dart';
import '../social/social_repositories.dart';
import 'profile_repository.dart';
import 'profile_collections.dart';
import 'profile_setup_screen.dart';
import 'profile_presentation.dart';
import '../gifts/gift_artwork.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int section = 0;
  Widget _actions(BuildContext context, String id, String? me) {
    return me == id
        ? FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileSetupScreen(edit: true),
              ),
            ),
            child: const Text('Edit profile'),
          )
        : Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  try {
                    final on = await ref.read(
                      isFollowingProvider(id).future,
                    );
                    final repo = ref.read(followRepositoryProvider);
                    on ? await repo.unfollow(id) : await repo.follow(id);
                    ref.invalidate(isFollowingProvider(id));
                    ref.invalidate(profileStatsProvider(id));
                    if (me != null) ref.invalidate(profileStatsProvider(me));
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to update follow. Retry.',
                          ),
                        ),
                      );
                  }
                },
                child: Text(
                  ref.watch(isFollowingProvider(id)).valueOrNull == true
                      ? 'Unfollow'
                      : 'Follow',
                ),
              ),
              OutlinedButton(
                onPressed: () => showProfileGiftSheet(context, id),
                child: const Text('Gift'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/chat/$id'),
                child: const Text('Chat'),
              ),
            ],
          );
  }

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
                  border: Border(top: BorderSide(color: NimzoStyle.line))),
              child: _actions(context, id, me))),
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
                  child: Stack(children: [
                    Container(
                      key: const ValueKey('profile-cover'),
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xff4b5563), Color(0xff111827)]),
                          image: cover == null
                              ? null
                              : DecorationImage(
                                  image: NetworkImage(cover),
                                  fit: BoxFit.cover)),
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: SafeArea(
                              bottom: false,
                              child: IconButton(
                                  onPressed: () {
                                    if (Navigator.of(context).canPop())
                                      Navigator.of(context).pop();
                                  },
                                  icon: const Icon(LucideIcons.chevronLeft,
                                      color: Colors.white)))),
                    ),
                    Positioned(
                        top: 90,
                        left: 16,
                        child: Container(
                            key: const ValueKey('profile-avatar'),
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: NimzoAvatar(
                                name: p.displayName ?? p.username ?? 'N',
                                url: image('avatars', p.avatarPath),
                                size: 70))),
                  ])),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.crown,
                          color: Color(0xfff59e0b), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        p.displayName ?? p.username ?? 'Nimzo user',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                      if (p.dateOfBirth != null)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 1),
                            decoration: BoxDecoration(
                                color: const Color(0xff2563eb),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                '${p.gender == "Female" ? "♀" : "♂"} ${(DateTime.now().difference(p.dateOfBirth!).inDays / 365.25).floor()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)))
                    ]),
                    Text(
                      'ID:${p.nimzoId} · ${p.countryName ?? p.countryCode ?? ''}',
                      style: const TextStyle(color: NimzoStyle.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (p.wealthLevel > 0)
                          LevelBadge(kind: 0, level: p.wealthLevel),
                        if (p.charmLevel > 0)
                          LevelBadge(kind: 1, level: p.charmLevel),
                        if (p.activeLevel > 0)
                          LevelBadge(kind: 2, level: p.activeLevel),
                        if (p.vipLevel > 0)
                          Chip(label: Text('VIP ${p.vipLevel}')),
                        if (p.svipLevel > 0)
                          Chip(label: Text('SVIP ${p.svipLevel}')),
                      ],
                    ),
                    Text(p.bio?.isNotEmpty == true ? p.bio! : 'No bio yet'),
                    AsyncContent(
                      value: ref.watch(profileStatsProvider(id)),
                      onRetry: () => ref.invalidate(profileStatsProvider(id)),
                      builder: (stats) => Row(
                        children: [
                          for (final key in [
                            'following',
                            'followers',
                            'visitors',
                          ])
                            Expanded(
                              child: InkWell(
                                  onTap: () => context.push('/social/$key/$id'),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${stats[key] ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(key),
                                      ],
                                    ),
                                  )),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AsyncContent(
                        value: ref.watch(profileTagsProvider(id)),
                        onRetry: () => ref.invalidate(profileTagsProvider(id)),
                        builder: (tags) =>
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (var i = 0; i < tags.length; i++)
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: [
                                          const Color(0xffdcfce7),
                                          const Color(0xffede9fe),
                                          const Color(0xfffce7f3),
                                          const Color(0xffe0f2fe)
                                        ][i % 4],
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Text(tags[i],
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: [
                                              const Color(0xff16a34a),
                                              const Color(0xff7c3aed),
                                              const Color(0xffdb2777),
                                              const Color(0xff0284c7)
                                            ][i % 4])))
                            ])),
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
                              onAdd:
                                  me == id ? () => context.push('/cp') : null);
                        final partner =
                            cp['user_a'] == id ? cp['user_b'] : cp['user_a'];
                        return AsyncContent(
                          value: ref.watch(profileProvider(partner)),
                          onRetry: () =>
                              ref.invalidate(profileProvider(partner)),
                          builder: (other) => CouplePanel(
                              name: p.displayName ?? 'N',
                              partner: other.displayName ??
                                  other.username ??
                                  'Nimzo user',
                              days: DateTime.tryParse(
                                          cp['created_at']?.toString() ?? '') ==
                                      null
                                  ? 0
                                  : DateTime.now()
                                      .difference(DateTime.parse(
                                          cp['created_at'].toString()))
                                      .inDays),
                        );
                      },
                    ),
                    if (me == id)
                      TextButton(
                        onPressed: () => context.push('/cp'),
                        child: const Text('CP invitations'),
                      ),
                    for (final kind in ProfileCollection.values) ...[
                      Text(
                        {
                          'medal': 'Medal Wall',
                          'frame': 'Frame',
                          'car': 'Car',
                        }[kind.name]!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                                        padding:
                                            const EdgeInsets.only(right: 10),
                                        child: CollectibleArtwork(item: item)),
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
                height: 150,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final item in g.take(limit ?? g.length))
                    SizedBox(
                        width: 86,
                        child: Column(children: [
                          SizedBox(
                              width: 46,
                              height: 44,
                              child: GiftArtwork(
                                  name: item['name'].toString(),
                                  assetPath: item['asset_path']?.toString())),
                          ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              title: Text(item['name'].toString(),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              subtitle: Text('× ${item['quantity']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11))),
                        ])),
                ])),
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

class LevelBadge extends StatelessWidget {
  final int kind, level;
  const LevelBadge({super.key, required this.kind, required this.level});
  static Color color(int kind, int level) {
    final band = level <= 20
        ? 0
        : level <= 39
            ? 1
            : level <= 59
                ? 2
                : level <= 79
                    ? 3
                    : level <= 99
                        ? 4
                        : 5;
    const families = [
      [0xff8b5e3c, 0xffa16d48, 0xff654321],
      [0xff15803d, 0xff16a34a, 0xff047857],
      [0xff1d4ed8, 0xff0284c7, 0xff4338ca],
      [0xffdb2777, 0xffbe185d, 0xffc026d3],
      [0xffdc2626, 0xffb91c1c, 0xffe11d48],
      [0xffb77900, 0xffa16207, 0xffca8a04],
    ];
    return Color(families[band][kind]);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color(kind, level),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              [LucideIcons.crown, LucideIcons.star, LucideIcons.zap][kind],
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
