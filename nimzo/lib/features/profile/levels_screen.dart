import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import 'profile_repository.dart';
import 'profile_screen.dart';

class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserIdProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Level')),
        body: id == null
            ? const EmptyContent('Please sign in.')
            : AsyncContent(
                value: ref.watch(profileProvider(id)),
                onRetry: () => ref.invalidate(profileProvider(id)),
                builder: (p) =>
                    ListView(padding: const EdgeInsets.all(16), children: [
                      for (final v in [
                        (0, 'Wealth', p.wealthLevel),
                        (1, 'Charm', p.charmLevel),
                        (2, 'Active', p.activeLevel)
                      ])
                        ReferenceCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                LevelBadge(kind: v.$1, level: v.$3),
                                const SizedBox(width: 12),
                                Expanded(child: Text('${v.$2} level')),
                                Text('${v.$3} / 120')
                              ]),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                  value: v.$3.clamp(0, 120) / 120,
                                  color: LevelBadge.color(v.$1, v.$3))
                            ]))
                    ])));
  }
}
