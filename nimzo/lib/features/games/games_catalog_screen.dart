import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'game_catalog.dart';

class GamesCatalogScreen extends StatelessWidget {
  final String? roomId;
  const GamesCatalogScreen({super.key, this.roomId});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Games')),
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
                      g.title,
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
