import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/reference_widgets.dart';
import '../honors/honor_milestone.dart';
import '../honors/honor_repository.dart';

/// Original NIMZO recognition evaluated from actual records, without rewards.
class HonorWallContent extends ConsumerStatefulWidget {
  const HonorWallContent({super.key});

  @override
  ConsumerState<HonorWallContent> createState() => _HonorWallState();
}

class _HonorWallState extends ConsumerState<HonorWallContent> {
  String category = 'All';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your NIMZO milestones',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Honors recognize recorded activity. They do not grant coins, '
            'diamonds or membership benefits. Self gifts do not count.',
          ),
          const SizedBox(height: 16),
          AsyncContent<List<HonorMilestone>>(
            value: ref.watch(honorMilestonesProvider),
            onRetry: () => ref.invalidate(honorMilestonesProvider),
            builder: (honors) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '${honors.where((h) => h.earned).length} of ${honors.length} earned',
                      key: const ValueKey('honor-earned-total'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh honors',
                    onPressed: () => ref.invalidate(honorMilestonesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ]),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final name in const [
                      'All',
                      'Giving',
                      'Appreciation',
                      'Games',
                      'Community'
                    ])
                      ChoiceChip(
                        label: Text(name),
                        selected: category == name,
                        onSelected: (_) => setState(() => category = name),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final honor in honors)
                  if (category == 'All' || category == honor.category)
                    HonorMilestoneCard(honor: honor),
                const SizedBox(height: 8),
                const Text(
                  'Original NIMZO rules · Updated from retained records. '
                  'Previously removed medals are not restored. '
                  'An earned date appears only when a recorded event proves it.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
}

class HonorMilestoneCard extends StatelessWidget {
  final HonorMilestone honor;
  const HonorMilestoneCard({super.key, required this.honor});

  IconData get symbol => switch (honor.category) {
        'Giving' => Icons.volunteer_activism_rounded,
        'Appreciation' => Icons.favorite_rounded,
        'Games' => Icons.sports_esports_rounded,
        _ => Icons.groups_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = honor.earned
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final date = honor.earnedAt?.toLocal();
    return Card(
      key: ValueKey('honor-${honor.code}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            label: honor.earned ? 'Earned honor' : 'Not earned yet',
            child: CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(symbol),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(honor.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(honor.description),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: honor.fraction,
                semanticsLabel: '${honor.title}, ${honor.progress} of ${honor.target}',
              ),
              const SizedBox(height: 6),
              Text(
                  '${honor.progress} / ${honor.target} · ${honor.earned ? 'Earned' : 'In progress'}'),
              if (honor.earned && date != null)
                Text(
                    'Earned ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}
