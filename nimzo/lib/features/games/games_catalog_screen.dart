import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'game_catalog.dart';
import '../../core/theme/app_theme.dart';

class GamesCatalogScreen extends StatefulWidget {
  final String? roomId;
  const GamesCatalogScreen({super.key, this.roomId});

  @override
  State<GamesCatalogScreen> createState() => _GamesCatalogState();
}

class _GamesCatalogState extends State<GamesCatalogScreen> {
  String filter = 'All';

  static const filters = <String>['All', 'Party', 'Slots', 'Cards'];

  static String kind(String slug) {
    if (slug == 'teen_patti') return 'Cards';
    if (slug == 'slot' || slug == 'fruit_party_jackpot') return 'Slots';
    if (slug == 'lucky_77') return 'Party';
    return 'Party';
  }

  Future<void> open(NimzoGame game) async {
    // The playable backend only exists for serverEnabled titles. Other
    // existing visual boards remain explicitly preview-only.
    final uri = Uri(
      path: '/games-play',
      queryParameters: <String, String>{
        'game': game.slug,
        if (widget.roomId != null) 'room': widget.roomId!,
      },
    );
    if (!mounted) return;
    await context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final games = NimzoRoomGames.approved.where(
      (g) => filter == 'All' || kind(g.slug) == filter,
    ).toList();
    return Scaffold(
      backgroundColor: const Color(0xfff6f4ff),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Games',
          style: TextStyle(color: Color(0xff23163f),
            fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 105),
        children: [
          Container(
            height: 166,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xff42218a), Color(0xff8c35e6),
                  Color(0xffd862d0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28)),
            child: Stack(children: [
              Positioned(right: -46, top: -58,
                child: CircleAvatar(
                  radius: 125,
                  backgroundColor: Colors.white.withValues(alpha: .09))),
              Positioned(right: 30, top: 18,
                child: const Icon(Icons.casino_rounded,
                  color: Color(0x70ffe6a1), size: 111)),
              const Positioned(
                left: 24, top: 29, bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIMZO GAMES',
                      style: TextStyle(
                        color: Color(0xffffd69b),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                    SizedBox(height: 9),
                    Text('Choose Your Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 9),
                    Text('Seven room game boards',
                      style: TextStyle(
                        color: Color(0xfff2e6ff), fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      key: ValueKey('game-category-$option'),
                      label: Text(option),
                      selected: filter == option,
                      onSelected: (_) => setState(() => filter = option),
                      selectedColor: const Color(0xffdfc4ff),
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: filter == option
                          ? NimzoStyle.primary
                          : const Color(0xff80738e),
                        fontWeight: FontWeight.w800),
                      side: BorderSide(
                        color: filter == option
                          ? NimzoStyle.primary
                          : NimzoStyle.line),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Game collection',
              style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xff2a2140)))),
            Text('${games.length} games',
              style: const TextStyle(
                color: Color(0xff8e80a7), fontSize: 13)),
          ]),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .80,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13),
            itemBuilder: (context, index) {
              final game = games[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                child: InkWell(
                  key: ValueKey('game-catalog-${game.slug}'),
                  onTap: () => open(game),
                  borderRadius: BorderRadius.circular(23),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: const Color(0xffeee9f7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x105b3d98),
                          blurRadius: 9,
                          offset: Offset(0, 3)),
                      ]),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
                      child: Column(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(fit: StackFit.expand, children: [
                              Image.asset(
                                'assets/reference/game/${game.artwork}.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                  const ColoredBox(
                                    color: Color(0xffeee5fa),
                                    child: Icon(Icons.sports_esports_rounded,
                                      color: NimzoStyle.primary, size: 51)),
                              ),
                              if (!game.serverEnabled)
                                const Positioned(
                                  right: 6, top: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xcc31204d),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(9))),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 4),
                                      child: Text('Preview',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff281b39),
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                        const SizedBox(height: 5),
                        Text(kind(game.slug),
                          style: const TextStyle(
                            color: Color(0xff8f83a6), fontSize: 11)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Game boards marked Preview are visual-only until their '
            'server-authoritative game rounds and payouts are available. '
            'No fake winnings or betting settlements are used.',
            style: TextStyle(
              color: Color(0xff91849e), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
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
                          ? 'Grady Lion'
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
