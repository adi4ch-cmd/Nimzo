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
              decoration: const BoxDecoration(gradient: NimzoStyle.gradient),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => context.push('/profile/$id'),
                    child: Row(
                      children: [
                        NimzoAvatar(
                          name: p.displayName ?? 'N',
                          size: 78,
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
                                '/info/${Uri.encodeComponent(k)}',
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
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _MenuRow(
                    items: const [
                      ('Task', LucideIcons.listChecks, '/info/Task'),
                      ('Store', LucideIcons.shoppingBag, '/info/Store'),
                      ('Ranking', LucideIcons.trophy, '/ranking'),
                      ('Honor Wall', LucideIcons.award, '/info/Honor%20Wall'),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ReferenceCard(
                          child: ListTile(
                            title: const Text('SVIP'),
                            subtitle: const Text('Check now ›'),
                            onTap: () => context.push('/svip'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ReferenceCard(
                          child: ListTile(
                            title: const Text('Wallet'),
                            subtitle: const Text('My Coins ›'),
                            onTap: () => context.push('/wallet'),
                          ),
                        ),
                      ),
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
                        EmptyContent('Ranking service is not available yet.'),
                      ],
                    ),
                  ),
                ],
              ),
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
  Widget build(BuildContext context) => ReferenceCard(
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.push(item.$3),
                  child: Column(
                    children: [
                      Icon(item.$2, color: NimzoStyle.primary),
                      const SizedBox(height: 6),
                      Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
