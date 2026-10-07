import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/reference_widgets.dart';
import 'leaderboard_repository.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});
  @override
  ConsumerState<RankingScreen> createState() => _State();
}

class _State extends ConsumerState<RankingScreen> {
  String kind = 'wealth', period = 'weekly';
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final k in ['wealth', 'charm', 'room'])
            ChoiceChip(
                label: Text(k),
                selected: kind == k,
                onSelected: (_) => setState(() => kind = k))
        ]),
        Wrap(spacing: 8, children: [
          for (final p in ['weekly', 'monthly'])
            ChoiceChip(
                label: Text(p),
                selected: period == p,
                onSelected: (_) => setState(() => period = p))
        ]),
        AsyncContent(
            value: ref.watch(leaderboardProvider((kind, period))),
            onRetry: () => ref.invalidate(leaderboardProvider((kind, period))),
            builder: (rows) => rows.isEmpty
                ? const EmptyContent('No rankings yet')
                : Column(children: [
                    for (var i = 0; i < rows.length; i++)
                      ListTile(
                          leading: Text('${i + 1}'),
                          title:
                              Text(rows[i]['name']?.toString() ?? 'Nimzo user'),
                          trailing: Text('${rows[i]['score']}'),
                          onTap: () => context.push(
                              '/${kind == 'room' ? 'room' : 'profile'}/${rows[i]['id']}'))
                  ])),
      ]));
}
