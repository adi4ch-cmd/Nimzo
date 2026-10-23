import 'dart:math' as math;
import '../../core/widgets/master_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'game_catalog.dart';
import 'dynamic_game_catalog.dart';
import 'game_presentation_catalog.dart';
import '../../core/widgets/published_image.dart';

class GamesCatalogScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const GamesCatalogScreen({super.key, this.roomId});
  @override
  ConsumerState<GamesCatalogScreen> createState() => _GamesCatalogState();
}

class _GamesCatalogState extends ConsumerState<GamesCatalogScreen> {
  String filter = 'All', query = '';
  static const filters = ['All', 'Party', 'Slots', 'Cards'];

  Future<void> open(NimzoGame game) async {
    final uri = Uri(path: '/games-play', queryParameters: {
      'game': game.slug,
      if (widget.roomId != null) 'room': widget.roomId!,
    });
    await context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final presentation = ref.watch(gamePresentationCatalogProvider);
    final flags = ref.watch(nimzoLiveGameFlagsProvider).valueOrNull ??
        const <String, bool>{};
    final games = NimzoRoomGames.all
        .where((g) =>
            isKnownGameEnabled(g.slug, flags) &&
            (filter == 'All' || presentation.categoryFor(g) == filter) &&
            presentation
                .titleFor(g)
                .toLowerCase()
                .contains(query.toLowerCase().trim()))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xfff5faf7),
      appBar: AppBar(
          backgroundColor: const Color(0xfff5faf7),
          title: const Text('Games',
              style: TextStyle(
                  color: Color(0xff153e30), fontWeight: FontWeight.w800))),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 105),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                      colors: [Color(0xff064e3b), Color(0xff13976d)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: Color(0xffffd783), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('NIMZO PLAY',
                              style: TextStyle(
                                  color: Color(0xffffd783),
                                  letterSpacing: 2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)))
                    ]),
                    SizedBox(height: 18),
                    Text('A little play.\nA lot of connection.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            height: 1.12)),
                    SizedBox(height: 12),
                    Text(
                        'Explore room games, free practice and board previews.',
                        style: TextStyle(
                            color: Color(0xffd9f5e8),
                            height: 1.5,
                            fontSize: 12)),
                  ]),
            ),
            const SizedBox(height: 20),
            TextField(
                key: const ValueKey('game-search-field'),
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                    hintText: 'Find a game',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 14),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final option in filters)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            key: ValueKey('game-category-$option'),
                            label: Text(option),
                            selected: filter == option,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => filter = option),
                            selectedColor: const Color(0xff087f5b),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                                color: filter == option
                                    ? Colors.white
                                    : const Color(0xff60756b),
                                fontWeight: FontWeight.w700),
                            side: BorderSide.none)),
                ])),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(
                  child: Text('Game collection',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xff153e30),
                          fontWeight: FontWeight.w800))),
              Text('${games.length} games',
                  style:
                      const TextStyle(color: Color(0xff60756b), fontSize: 12))
            ]),
            const SizedBox(height: 14),
            if (games.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No games match your search.')),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: games.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 212 +
                          (MediaQuery.textScalerOf(context).scale(36) - 36),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12),
                  itemBuilder: (_, index) {
                    final game = games[index];
                    final status = game.serverEnabled
                        ? 'Room coins'
                        : NimzoRoomGames.isPractice(game.slug)
                            ? 'Practice'
                            : 'Preview';
                    return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            key: ValueKey('game-catalog-${game.slug}'),
                            onTap: () => open(game),
                            child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    GameCatalogArtwork(
                                                        game: game),
                                                    Positioned(
                                                        left: 7,
                                                        top: 7,
                                                        child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        7,
                                                                    vertical:
                                                                        4),
                                                            decoration: BoxDecoration(
                                                                color: const Color(
                                                                    0xe6064e3b),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8)),
                                                            child: Text(status,
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700)))),
                                                  ]))),
                                      const SizedBox(height: 11),
                                      Text(presentation.titleFor(game),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xff153e30),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(presentation.categoryFor(game),
                                          style: const TextStyle(
                                              color: Color(0xff60756b),
                                              fontSize: 11)),
                                    ]))));
                  });
            }),
            const SizedBox(height: 20),
            const Text(
                'Practice uses free demo chips only. Preview boards have no live game service. '
                'Fruit Party and Fruit Wheel use server-confirmed coin rounds in a voice room.',
                style: TextStyle(
                    color: Color(0xff60756b), fontSize: 11, height: 1.5)),
          ]),
    );
  }
}

/// Existing approved cover art is preserved. Fruit engines get original NIMZO
/// artwork, rather than covers for a different game or an unverified APK sprite.
class GameCatalogArtwork extends ConsumerWidget {
  const GameCatalogArtwork({super.key, required this.game});
  final NimzoGame game;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image =
        ref.watch(gamePresentationCatalogProvider).games[game.slug]?.image;
    final fallback = _originalArtwork();
    if (image != null) {
      return PublishedImage(
          url: image.url,
          publication: image.publication,
          fit: BoxFit.cover,
          unavailable: fallback);
    }
    return fallback;
  }

  Widget _originalArtwork() {
    if (game.serverEnabled) {
      return DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xffe4f4d6), Color(0xffffe4a8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: CustomPaint(
            painter: _FruitCoverPainter(wheel: game.slug == 'fruit_wheel'),
            child: const SizedBox.expand(),
          ));
    }
    return Image.asset('assets/reference/game/${game.artwork}.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xffe4f4d6),
            child: Icon(Icons.sports_esports_rounded,
                color: Color(0xff087f5b), size: 48)));
  }
}

/// Original vector cover illustrations with no decoder or sprite dependency.
/// These are catalog art; they never depict or calculate a game outcome.
class _FruitCoverPainter extends CustomPainter {
  const _FruitCoverPainter({required this.wheel});
  final bool wheel;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final unit = math.min(size.width, size.height);
    final paint = Paint()..isAntiAlias = true;
    if (wheel) {
      paint.color = const Color(0xffd8a94d);
      canvas.drawCircle(center + const Offset(0, 4), unit * .37, paint);
      paint.color = const Color(0xfffff7d8);
      canvas.drawCircle(center, unit * .37, paint);
      paint.color = const Color(0xfff0d28b);
      canvas.drawCircle(center, unit * .32, paint);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final fruit =
            center + Offset(math.cos(angle), math.sin(angle)) * (unit * .245);
        _fruit(canvas, fruit, unit * .062, i.isEven);
      }
      paint.color = const Color(0xff087f5b);
      canvas.drawCircle(center, unit * .105, paint);
      paint.color = const Color(0xffffdc86);
      final arrow = Path()
        ..moveTo(center.dx, center.dy - unit * .4)
        ..lineTo(center.dx - unit * .055, center.dy - unit * .49)
        ..lineTo(center.dx + unit * .055, center.dy - unit * .49)
        ..close();
      canvas.drawPath(arrow, paint);
    } else {
      final frame = Rect.fromCenter(
          center: center, width: unit * .82, height: unit * .48);
      paint.color = const Color(0xffc5953d);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              frame.shift(const Offset(0, 4)), const Radius.circular(14)),
          paint);
      paint.color = const Color(0xffffdf8e);
      canvas.drawRRect(
          RRect.fromRectAndRadius(frame, const Radius.circular(14)), paint);
      for (var i = 0; i < 3; i++) {
        final fruit = center + Offset((i - 1) * unit * .25, 0);
        paint.color = const Color(0xfffffdf2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: fruit, width: unit * .22, height: unit * .34),
                const Radius.circular(8)),
            paint);
        _fruit(canvas, fruit, unit * .075, i == 1);
      }
    }
  }

  void _fruit(Canvas canvas, Offset center, double radius, bool berry) {
    final paint = Paint()
      ..color = berry ? const Color(0xffe36c59) : const Color(0xfff7b735);
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0xff208656);
    canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(radius * .35, -radius),
            width: radius,
            height: radius * .45),
        paint);
    paint.color = const Color(0x80ffffff);
    canvas.drawCircle(
        center + Offset(-radius * .3, -radius * .25), radius * .2, paint);
  }

  @override
  bool shouldRepaint(_FruitCoverPainter oldDelegate) =>
      wheel != oldDelegate.wheel;
}

Future<void> showRoomGamesSheet(
  BuildContext context,
  String roomId, {
  ValueChanged<String>? onSelected,
}) async {
  final selected = await showReferenceSheet<String>(
    context,
    Consumer(
        builder: (sheetContext, ref, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GradientText('Games',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent:
                      100 * MediaQuery.textScalerOf(context).scale(1),
                  children: [
                    for (final game in NimzoRoomGames.all.where(
                      (g) => isKnownGameEnabled(
                        g.slug,
                        ref.watch(nimzoLiveGameFlagsProvider).valueOrNull ??
                            const <String, bool>{},
                      ),
                    ))
                      InkWell(
                        onTap: () => Navigator.pop(context, game.slug),
                        child: Column(
                          children: [
                            Flexible(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: GameCatalogArtwork(game: game)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref
                                  .watch(gamePresentationCatalogProvider)
                                  .titleFor(game),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            )),
  );
  if (selected != null && context.mounted) {
    if (onSelected != null) {
      onSelected(selected);
    } else {
      context.push('/games-play?game=$selected&room=$roomId');
    }
  }
}
