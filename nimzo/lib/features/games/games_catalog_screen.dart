import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'game_catalog.dart';
import '../../core/theme/app_theme.dart';

class GamesCatalogScreen extends StatelessWidget {
  final String? roomId;
  const GamesCatalogScreen({super.key, this.roomId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const GradientText('Games')),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: NimzoStyle.heroGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sports_esports_rounded,
                      color: Colors.white, size: 34),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Game Zone',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          )),
                        SizedBox(height: 3),
                        Text('Choose a game to play',
                          style: TextStyle(
                            color: Color(0xfff3eaff),
                            fontSize: 12,
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: .76,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final g in NimzoRoomGames.approved)
              InkWell(
                onTap: () => context.push(
                  '/games-play?game=${g.slug}${roomId == null ? '' : '&room=$roomId'}',
                ),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: NimzoStyle.primary.withValues(alpha: .23)),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x126628cf),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/reference/game/${g.artwork}.jpg',
                          height: 64,
                          width: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.sports_esports_rounded,
                            color: NimzoStyle.primary,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        g.artwork == 1
                            ? 'Grady Pro'
                            : g.artwork == 3
                                ? 'Slot Jackpots'
                                : g.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: NimzoStyle.ink,
                          fontWeight: FontWeight.w700,
                        ),
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
        const GradientText('Games',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
