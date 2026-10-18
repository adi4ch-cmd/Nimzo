import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/theme/app_theme.dart';
import 'leaderboard_repository.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});
  @override
  ConsumerState<RankingScreen> createState() => _State();
}

class _State extends ConsumerState<RankingScreen> {
  int category = 1, period = 1;
  @override
  Widget build(BuildContext context) {
    final key = (
      category == 1 ? 'wealth' : 'charm',
      period == 1 ? 'weekly' : 'monthly',
    );
    final supported = (category == 1 || category == 2) && period > 0;
    return Scaffold(
      backgroundColor: const Color(0xfff6f4ff),
      appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xff8944ed),
          title: const Text('Ranking',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16))),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          ReferenceTabs(
            labels: const ['Gift', 'Wealth', 'Charm', 'Active'],
            selected: category,
            onSelected: (i) => setState(() => category = i),
          ),
          const SizedBox(height: 12),
          ReferenceTabs(
            labels: const ['Daily', 'Weekly', 'Monthly'],
            selected: period,
            onSelected: (i) => setState(() => period = i),
            pills: true,
          ),
          const SizedBox(height: 12),
          if (!supported)
            const EmptyContent(
                'Only verified Wealth/Charm weekly and monthly rankings are available.')
          else
            AsyncContent(
              value: ref.watch(leaderboardProvider(key)),
              onRetry: () => ref.invalidate(leaderboardProvider(key)),
              builder: (rows) => rows.isEmpty
                  ? const EmptyContent('No rankings yet')
                  : Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(color: NimzoStyle.line),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: NimzoStyle.muted,
                                      ),
                                    ),
                                  ),
                                  NimzoAvatar(
                                    name: rows[i]['name']?.toString() ?? 'N',
                                  ),
                                ],
                              ),
                              title: Text(
                                rows[i]['name']?.toString() ?? 'Nimzo user',
                              ),
                              trailing: Text(
                                '${rows[i]['score']}',
                                style: const TextStyle(
                                  color: NimzoStyle.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () =>
                                  context.push('/profile/${rows[i]['id']}'),
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class RankingPodium extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const RankingPodium({super.key, required this.rows});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final i in [1, 0, 2])
              if (i < rows.length)
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/profile/${rows[i]['id']}'),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == 0 ? 16 : 0),
                      child: Column(
                        children: [
                          NimzoAvatar(
                            name: rows[i]['name']?.toString() ?? 'N',
                            size: i == 0 ? 68 : 54,
                          ),
                          Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Color(0xfff59e0b),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            rows[i]['name']?.toString() ?? 'Nimzo user',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${rows[i]['score']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: NimzoStyle.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
}
