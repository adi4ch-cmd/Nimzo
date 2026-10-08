import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/theme/app_theme.dart';
import 'profile_repository.dart';
import 'profile_screen.dart';

class LevelsScreen extends ConsumerStatefulWidget {
  const LevelsScreen({super.key});
  @override
  ConsumerState<LevelsScreen> createState() => _LevelState();
}

class _LevelState extends ConsumerState<LevelsScreen> {
  int selected = 0;
  static const bands = [
    (1, 20, 'Brown', Color(0xffa16207)),
    (21, 39, 'Green', Color(0xff16a34a)),
    (40, 59, 'Blue', Color(0xff2563eb)),
    (60, 79, 'Pink', Color(0xffdb2777)),
    (80, 99, 'Red', Color(0xffdc2626)),
    (100, 120, 'Gold', Color(0xffd4a017))
  ];
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider),
        label = ['Wealth', 'Charm', 'Active'][selected];
    return Scaffold(
        appBar: AppBar(title: const Text('Level')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ReferenceTabs(
              labels: const ['Wealth', 'Charm', 'Active'],
              selected: selected,
              onSelected: (i) => setState(() => selected = i)),
          const SizedBox(height: 12),
          if (id == null)
            const EmptyContent('Please sign in.')
          else
            AsyncContent(
                value: ref.watch(profileProvider(id)),
                onRetry: () => ref.invalidate(profileProvider(id)),
                builder: (p) {
                  final level =
                      [p.wealthLevel, p.charmLevel, p.activeLevel][selected];
                  final total = [
                    p.wealthCoins,
                    p.charmDiamonds,
                    p.activePoints
                  ][selected];
                  final band = bands
                      .where((b) => level >= b.$1 && level <= b.$2)
                      .firstOrNull;
                  return ReferenceCard(
                      child: Column(children: [
                    Transform.scale(
                        scale: 1.4,
                        child: LevelBadge(kind: selected, level: level)),
                    const SizedBox(height: 16),
                    Text('Tier: ${band?.$3 ?? 'Not started'}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text('Level $level / 120',
                        style: const TextStyle(color: NimzoStyle.muted)),
                    const SizedBox(height: 6),
                    Text(
                        total == null
                            ? 'XP progress unavailable'
                            : '${referenceNumber(total)} ${[
                                'coins sent',
                                'diamonds received',
                                'activity points'
                              ][selected]} · next-level threshold unavailable',
                        style: const TextStyle(
                            color: NimzoStyle.muted, fontSize: 12))
                  ]));
                }),
          ReferenceCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('How $label grows',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    [
                      'Grows when you send gifts.',
                      'Grows when you receive gifts.',
                      'Grows while you stay active.'
                    ][selected],
                    style:
                        const TextStyle(color: NimzoStyle.muted, fontSize: 12))
              ])),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Tier colors',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          for (final band in bands)
            Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: NimzoStyle.line))),
                child: Row(children: [
                  Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: band.$4)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(band.$3)),
                  Text('Level ${band.$1}-${band.$2}',
                      style: const TextStyle(color: NimzoStyle.muted))
                ])),
        ]));
  }
}
