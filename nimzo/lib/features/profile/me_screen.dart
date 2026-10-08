import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reference_widgets.dart';
import 'profile_repository.dart';
import 'profile_screen.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserIdProvider);
    if (id == null)
      return const Scaffold(body: EmptyContent('Please sign in.'));
    return Scaffold(
      backgroundColor: const Color(0xfff7f3fc),
      body: AsyncContent(
        value: ref.watch(profileProvider(id)),
        onRetry: () => ref.invalidate(profileProvider(id)),
        builder: (p) => ListView(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 44),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                    Color(0xff9333ea),
                    Color(0xffc026d3),
                    Color(0xffd946ef)
                  ],
                      stops: [
                    0,
                    .7,
                    1
                  ])),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => context.push('/profile/$id'),
                    child: Row(
                      children: [
                        NimzoAvatar(
                          name: p.displayName ?? 'N',
                          size: 78,
                          borderWidth: 3,
                          backgroundColor: NimzoStyle.ink,
                          url: p.avatarPath == null
                              ? null
                              : ref
                                  .read(supabaseProvider)
                                  .storage
                                  .from('avatars')
                                  .getPublicUrl(p.avatarPath!),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayName ?? p.username ?? 'Nimzo user',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'ID:${p.nimzoId} | ${p.countryName ?? p.countryCode ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (p.wealthLevel > 0)
                        LevelBadge(kind: 0, level: p.wealthLevel),
                      if (p.charmLevel > 0)
                        LevelBadge(kind: 1, level: p.charmLevel),
                      if (p.activeLevel > 0)
                        LevelBadge(kind: 2, level: p.activeLevel),
                    ],
                  ),
                  AsyncContent(
                    value: ref.watch(profileStatsProvider(id)),
                    onRetry: () => ref.invalidate(profileStatsProvider(id)),
                    builder: (stats) => Row(
                      children: [
                        for (final k in ['following', 'followers', 'visitors'])
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.push(
                                '/social/$k/$id',
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${stats[k] ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    k,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    children: [
                      _MenuRow(
                        items: const [
                          ('Task', LucideIcons.listChecks, '/info/Task'),
                          ('Store', LucideIcons.shoppingBag, '/info/Store'),
                          ('Ranking', LucideIcons.trophy, '/ranking'),
                          (
                            'Honor Wall',
                            LucideIcons.award,
                            '/info/Honor%20Wall'
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: _FeatureBanner(
                                  title: 'SVIP',
                                  subtitle: 'Check now ›',
                                  colors: const [
                                    Color(0xfffff3d1),
                                    Color(0xfffff9e8)
                                  ],
                                  onTap: () => context.push('/svip'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _FeatureBanner(
                                  title: 'Wallet',
                                  subtitle: 'My Coins ›',
                                  colors: const [
                                    Color(0xffffe3ec),
                                    Color(0xfffff0f4)
                                  ],
                                  onTap: () => context.push('/wallet'))),
                        ],
                      ),
                      _MenuRow(
                        items: const [
                          ('CP Zone', LucideIcons.heart, '/cp'),
                          ('VIP', LucideIcons.crown, '/vip'),
                          ('Settings', LucideIcons.settings, '/settings'),
                          ('Level', LucideIcons.chartNoAxesColumn, '/levels'),
                          ('About', LucideIcons.info, '/info/About'),
                        ],
                      ),
                      const ReferenceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1M+ Gift Live Ranking',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            EmptyContent(
                                'Ranking service is not available yet.'),
                          ],
                        ),
                      ),
                    ],
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final List<(String, IconData, String)> items;
  const _MenuRow({required this.items});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x147828c8),
                  offset: Offset(0, 2),
                  blurRadius: 10)
            ]),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.push(item.$3),
                  child: Column(
                    children: [
                      Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                              color: (item.$1 == 'Ranking' || item.$1 == 'VIP'
                                      ? const Color(0xfff59e0b)
                                      : item.$1 == 'Task' ||
                                              item.$1 == 'CP Zone' ||
                                              item.$1 == 'About'
                                          ? NimzoStyle.pink
                                          : NimzoStyle.primary)
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(item.$2,
                              size: 26,
                              color: item.$1 == 'Ranking' || item.$1 == 'VIP'
                                  ? const Color(0xfff59e0b)
                                  : item.$1 == 'Task' ||
                                          item.$1 == 'CP Zone' ||
                                          item.$1 == 'About'
                                      ? NimzoStyle.pink
                                      : NimzoStyle.primary)),
                      const SizedBox(height: 6),
                      Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class _FeatureBanner extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const _FeatureBanner(
      {required this.title,
      required this.subtitle,
      required this.colors,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          borderRadius: BorderRadius.circular(14),
          child: Ink(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14)),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: NimzoStyle.muted, fontSize: 12))
                          ]))))));
}
