import 'dart:math';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wallet/wallet_screen.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/utils/formatters.dart';
import 'game_catalog.dart';

/// Visual boards from nimzo-ui-2.html. Settlement is never simulated locally.
class GameScreen extends ConsumerStatefulWidget {
  final String? roomId, slug;
  final VoidCallback? onMinimize, onClose, onExpand;
  final bool expanded;
  final Widget? roomControls;
  const GameScreen({
    super.key,
    this.roomId,
    this.slug,
    this.onMinimize,
    this.onClose,
    this.onExpand,
    this.expanded = false,
    this.roomControls,
  });
  static const fruit = [
    'Orange',
    'Kiwi',
    'Apple',
    'Avocado',
    'Watermelon',
    'Lemon',
    'Mango',
    'Pomegranate',
  ];
  static const grady = [
    'Tomato',
    'Mushroom',
    'Onion',
    'Shaljam',
    'Pizza',
    'Meat',
    'Fish',
    'Jinga',
    'Chicken',
    'Mixed Meat',
  ];
  static const cars = [
    'BMW',
    'Porsche',
    'Land Rover',
    'Ferrari',
    'Lamborghini',
    'Bugatti',
    'Rolls-Royce',
    'Mercedes',
  ];
  @override
  ConsumerState<GameScreen> createState() => _GameState();
}

class _GameState extends ConsumerState<GameScreen> {
  int selectedChip = 0;
  final Set<int> _previewOptions = {};
  static const gold = Color(0xfffde68a);
  static const multipliers = [
    [5, 5, 5, 45, 5, 25, 15, 10],
    [5, 5, 5, 5, 0, 10, 15, 25, 45, 0],
    [8, 18, 66, 50, 100, 88, 30, 20],
    [],
    [2, 9, 2],
    [],
    [2.5, 6, 2.5],
  ];
  static const colors = [
    [
      0xffea580c,
      0xff7c3aed,
      0xff16a34a,
      0xff0284c7,
      0xffdb2777,
      0xff0d9488,
      0xff8b5cf6,
      0xffdc2626,
    ],
    [
      0xff15803d,
      0xff15803d,
      0xff15803d,
      0xff15803d,
      0xffb45309,
      0xff1d4ed8,
      0xff1d4ed8,
      0xff1d4ed8,
      0xff1d4ed8,
      0xff6d28d9,
    ],
    [
      0xff1d4ed8,
      0xffbe123c,
      0xff15803d,
      0xffdc2626,
      0xffca8a04,
      0xff0e7490,
      0xff6d28d9,
      0xff475569,
    ],
    [],
    [0xff1d4ed8, 0xff7c3aed, 0xff0f766e],
    [],
    [0xffb91c1c, 0xff475569, 0xff1d4ed8],
  ];
  static const chips = [
    [100, 10000, 100000, 1000000, 10000000],
    [5000, 10000, 50000, 100000, 500000],
    [100, 10000, 100000, 1000000, 10000000],
    [5000, 10000, 50000, 100000, 500000],
    [100, 1000, 10000, 100000, 1000000],
    [100, 1000, 10000, 100000, 1000000],
    [100, 1000, 10000, 100000, 1000000],
  ];
  @override
  Widget build(BuildContext context) {
    final game =
        NimzoRoomGames.approved
            .where((g) => g.slug == widget.slug)
            .firstOrNull ??
        NimzoRoomGames.approved.first;
    final i = game.artwork,
        title = i == 1
            ? 'Grady Pro'
            : i == 3
            ? 'Slot Jackpots'
            : game.title;
    final spin = i == 3 || i == 5;
    final wallet = ref.watch(walletProvider).valueOrNull;
    final options = i == 0
        ? GameScreen.fruit
        : i == 1
        ? GameScreen.grady
        : i == 2
        ? GameScreen.cars
        : i == 4
        ? ['Player A', 'Player B', 'Player C']
        : ['Home', 'Draw', 'Away'];
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff14052e),
        appBar: AppBar(
          toolbarHeight: 60,
          backgroundColor: const Color(0xff3b0f7a),
          foregroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          leading: widget.onClose == null
              ? null
              : IconButton(
                  tooltip: 'Close game',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
          actions: [
            if (widget.onExpand != null)
              IconButton(
                tooltip: widget.expanded ? 'Collapse game' : 'Expand game',
                onPressed: widget.onExpand,
                icon: Icon(
                  widget.expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
              ),
            if (widget.onMinimize != null)
              IconButton(
                tooltip: 'Return to voice room',
                onPressed: widget.onMinimize,
                icon: const Icon(Icons.picture_in_picture_alt),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Rules',
                      onPressed: () => showReferenceSheet(
                        context,
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$title · Rules',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'This is the approved visual reference. Displayed options and multipliers are not a complete approved gameplay contract.',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              i == 4
                                  ? 'Teen Patti identity requires confirmation: the reference shows Player A/B/C. Traditional Teen Patti rules have not been approved.'
                                  : i == 6
                                  ? 'Bounty Football is the seventh catalog entry. The reference shows Home/Draw/Away; match source and settlement rules require approval.'
                                  : 'Round timing, outcome source, wager limits and settlement rules require an approved server contract.',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Game service unavailable.',
                              style: TextStyle(color: Color(0xff6b7a72)),
                            ),
                          ],
                        ),
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(24, 22),
                        maximumSize: const Size(24, 22),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Text(
                        '?',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        wallet == null
                            ? 'Balance unavailable'
                            : '${referenceNumber(wallet.coins)} coins',
                        style: const TextStyle(color: gold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.roomControls,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff3b0f7a), Color(0xff14052e)],
            ),
          ),
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff5b268e), Color(0xff271046)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: gold.withValues(alpha: .3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/reference/game/${game.artwork}.jpg',
                        width: 48,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Game service unavailable',
                            style: TextStyle(
                              color: gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Board preview only. Approved rules and live service are pending.',
                            style: TextStyle(
                              color: Color(0xffe9d5ff),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!spin)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            child: Text(
                              'Round —',
                              style: TextStyle(
                                color: Color(0xffe9d5ff),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            child: Text(
                              'Time —',
                              style: TextStyle(
                                color: Color(0xffe9d5ff),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            child: Text(
                              'Total bet —',
                              style: TextStyle(
                                color: Color(0xffe9d5ff),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (i == 5)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 190,
                      child: CustomPaint(painter: _WheelPainter()),
                    ),
                  ),
                )
              else if (i == 3) ...[
                Row(
                  children: [
                    for (final label in ['GRAND', 'MAJOR', 'MINOR', 'MINI'])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(label, style: const TextStyle(fontSize: 11)),
                              const Text(
                                '—',
                                style: TextStyle(
                                  color: gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xfff59e0b),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: 70,
                    children: [
                      for (var n = 0; n < 15; n++)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff0f0a26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/reference/slot/${n * 5 % 12}.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                ),
              ] else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: i == 1 ? 5 : 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent:
                      (i == 2
                          ? 128.0
                          : i == 4 || i == 6
                          ? 144.0
                          : 112.0) *
                      MediaQuery.textScalerOf(context).scale(1),
                  children: [
                    for (
                      var n = 0;
                      n < options.length + ((i == 0 || i == 2) ? 1 : 0);
                      n++
                    )
                      if ((i == 0 || i == 2) && n == 4)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff1b0b3a),
                            border: Border.all(
                              color: const Color(0xfffacc15),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Drawing Time',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        )
                      else
                        _tile(
                          i,
                          (i == 0 || i == 2) && n > 4 ? n - 1 : n,
                          options,
                        ),
                  ],
                ),
              if (i == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      for (var k = 0; k < 8; k++)
                        Expanded(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/reference/fruit/$k.jpg',
                                height: 30,
                                fit: BoxFit.cover,
                              ),
                              Text(
                                '${multipliers[0][k]}x',
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (!spin)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Potential win',
                          style: TextStyle(
                            color: Color(0xffe9d5ff),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('—', style: TextStyle(color: gold, fontSize: 12)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Profit  On result',
                          style: TextStyle(
                            color: Color(0xffe9d5ff),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Text(
                  'Results unavailable',
                  style: TextStyle(color: Color(0xffe9d5ff), fontSize: 12),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var k = 0; k < chips[i].length; k++)
                    Semantics(
                      button: true,
                      label: '${chips[i][k]} coins, preview amount',
                      selected: selectedChip == k,
                      child: InkWell(
                        onTap: () => setState(() => selectedChip = k),
                        child: CustomPaint(
                          foregroundPainter: const _ChipEdgePainter(),
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedChip == k
                                  ? const Color(0xfff59e0b)
                                  : const Color(0xff7c3aed),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 4,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                compactNumber(chips[i][k]).replaceAll('.0', ''),
                                style: TextStyle(
                                  color: selectedChip == k
                                      ? const Color(0xff3b0764)
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!spin) ...[
                    const Expanded(
                      child: GradientButton(
                        onPressed: null,
                        gradient: LinearGradient(
                          colors: [Color(0xffec4899), Color(0xffec4899)],
                        ),
                        child: Text('Auto Play'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      onPressed: null,
                      foreground: const Color(0xff3b0764),
                      gradient: const LinearGradient(
                        colors: [Color(0xfffbbf24), Color(0xfffbbf24)],
                      ),
                      child: Text(
                        spin ? 'Spin unavailable' : 'Betting unavailable',
                      ),
                    ),
                  ),
                ],
              ),
              if (!spin)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Max ${i == 4 || i == 6 ? 3 : 6} bets · each can have a different amount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffc4b5fd),
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  widget.roomId == null
                      ? 'Open a room to access in-room games.'
                      : 'Game service unavailable. No coins will be spent.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xffc4b5fd),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(int game, int index, List<String> names) {
    final special = game == 1 && (index == 4 || index == 9);
    return Semantics(
      button: true,
      selected: _previewOptions.contains(index),
      label: '${names[index]}, preview selection only',
      child: InkWell(
        onTap: () => setState(() {
          if (!_previewOptions.remove(index)) _previewOptions.add(index);
        }),
        child: Container(
          decoration: BoxDecoration(
            color: Color(colors[game][index]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _previewOptions.contains(index) || special
                  ? const Color(0xfff59e0b)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (game == 2)
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Colors.white, Color(0xff9ca3af)],
                    ),
                    border: Border.all(color: gold, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      ['BM', 'PO', 'LR', 'FE', 'LB', 'BU', 'RR', 'MB'][index],
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 56,
                  child: Image.asset(
                    'assets/reference/${game == 0
                        ? 'fruit'
                        : game == 1
                        ? 'grady'
                        : 'game'}/${game == 4
                        ? 4
                        : game == 6
                        ? 6
                        : index}.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (game != 0 && game != 1)
                Text(
                  names[index],
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  special ? 'SPECIAL' : '${multipliers[game][index]}x',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: gold,
                    fontSize: special ? 12 : 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (special)
                FittedBox(
                  child: Text(
                    index == 4 ? 'All 4 upper' : 'All 4 lower',
                    style: const TextStyle(fontSize: 9, height: 1),
                  ),
                )
              else if (game == 4 || game == 6)
                Text(
                  game == 4
                      ? [
                          'A♠ K♠ Q♥ · 1:1',
                          'A♥ A♦ A♣ · 1:8',
                          'K♠ Q♠ J♥ · 1:1',
                        ][index]
                      : ['1:1.5', '1:5', '1:1.5'][index],
                  style: const TextStyle(fontSize: 10, height: 1),
                ),
              if (!special)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _previewOptions.contains(index) ? '✓' : '+',
                    style: const TextStyle(fontSize: 12, height: 1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2), r = size.width / 2;
    const colors = [
      0xfff43f5e,
      0xff22c55e,
      0xfffacc15,
      0xff3b82f6,
      0xffec4899,
      0xfff97316,
      0xffa855f7,
      0xff06b6d4,
    ];
    const labels = ['x2', 'x5', 'x10', 'x20', 'x50', 'x100', 'x150', 'x5'];
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * pi / 4 - pi / 2,
        pi / 4,
        true,
        Paint()..color = Color(colors[i]),
      );
      final angle = i * pi / 4 + pi / 8 - pi / 2;
      final t = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle + pi / 2);
      t.paint(canvas, Offset(-t.width / 2, -68 - t.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      r - 3,
      Paint()
        ..color = const Color(0xfff59e0b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xfffff7e0));
    final t = TextPainter(
      text: const TextSpan(
        text: '77',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xff92400e),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(canvas, center - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => false;
}

class _ChipEdgePainter extends CustomPainter {
  const _ChipEdgePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var i = 0; i < 16; i++)
      canvas.drawArc(rect, i * pi / 8, pi / 12, false, paint);
  }

  @override
  bool shouldRepaint(_ChipEdgePainter old) => false;
}
