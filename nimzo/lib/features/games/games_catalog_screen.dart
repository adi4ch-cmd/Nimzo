import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'game_catalog.dart';

class GamesCatalogScreen extends StatelessWidget {
  final String? roomId;
  const GamesCatalogScreen({super.key, this.roomId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const GradientText('Games')),
    body: GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final g in NimzoRoomGames.approved)
          InkWell(
            onTap: () => context.push(
              '/games-play?game=${g.slug}${roomId == null ? '' : '&room=$roomId'}',
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/reference/game/${g.artwork}.jpg',
                    height: 64,
                    width: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  g.artwork == 1
                      ? 'Grady Pro'
                      : g.artwork == 3
                      ? 'Slot Jackpots'
                      : g.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Future<void> showRoomGamesSheet(
  BuildContext context,
  String roomId, {
  ValueChanged<String>? onSelected,
}) async {
  final selected = await showReferenceSheet<String>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Games',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 100 * MediaQuery.textScalerOf(context).scale(1),
          children: [
            for (final game in NimzoRoomGames.approved)
              InkWell(
                onTap: () => Navigator.pop(context, game.slug),
                child: Column(
                  children: [
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/reference/game/${game.artwork}.jpg',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.artwork == 1
                          ? 'Grady Pro'
                          : game.artwork == 3
                          ? 'Slot Jackpots'
                          : game.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  if (selected != null && context.mounted) {
    if (onSelected != null) {
      onSelected(selected);
    } else {
      context.push('/games-play?game=$selected&room=$roomId');
    }
  }
}
