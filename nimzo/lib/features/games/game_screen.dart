import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wallet/wallet_screen.dart';
import 'game_repository.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const GameScreen({super.key, this.roomId});
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  String game = 'fruit_wheel';
  final _bet = TextEditingController(text: '1000');
  late final AnimationController _angle = AnimationController.unbounded(
    vsync: this,
  );
  bool busy = false;
  Map<String, dynamic>? result;
  String? _key;
  String? _request;
  int _lastBet = 0;

  @override
  void dispose() {
    _angle.dispose();
    _bet.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final amount = int.tryParse(_bet.text.trim()) ?? 0;
    if (busy) return;
    if (amount < 1 || amount > 500000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bet must be 1 to 500,000 coins.')),
      );
      return;
    }
    if (widget.roomId == null || widget.roomId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join a room to play.')),
      );
      return;
    }
    final request = '${widget.roomId}:$game:$amount';
    if (request != _request || _key == null) {
      _request = request;
      _key =
          'app-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    }
    setState(() {
      busy = true;
      result = null;
    });
    if (game == 'fruit_wheel')
      _angle.repeat(min: 0, max: 2 * pi, period: const Duration(seconds: 1));
    try {
      final r = await ref
          .read(gameRepositoryProvider)
          .play(roomId: widget.roomId, game: game, bet: amount, key: _key!);
      ref.invalidate(walletProvider);
      if (!mounted) return;
      _angle.stop();
      if (game == 'fruit_wheel') {
        final segments = ref.read(wheelSegmentsProvider).valueOrNull ?? [];
        final position = segments.indexWhere(
          (s) => s['segment_no'] == (r['result'] as Map?)?['segment'],
        );
        if (position >= 0 && segments.isNotEmpty) {
          final target = -2 * pi * (position + .5) / segments.length;
          final correction = (target - _angle.value) % (2 * pi);
          await _angle.animateTo(
            _angle.value + 2 * pi + correction,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
          );
        }
      }
      if (mounted)
        setState(() {
          result = r;
          _lastBet = amount;
          _key = null;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        _angle.stop();
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    final outcome = r?['result'] as Map?;
    final payout = (r?['payout'] as num?)?.toInt() ?? 0;
    final segments = ref.watch(wheelSegmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Room games')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.roomId == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Open a voice room to play games with coins.'),
              ),
            ),
          Text(
            'Games',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const <(String, String, bool)>[
                ('fruit_party', 'Fruit Party', true),
                ('fruit_wheel', 'Fruit Wheel', true),
                ('fruit_party_jackpot', 'Fruit Party Jackpot', false),
                ('lucky_wheel_77', 'Lucky Wheel 77', false),
                ('grady_lion', 'Grady Lion', false),
                ('bigetar', 'Bigetar', false),
                ('slot', 'Slot', false),
                ('teen_patti', 'Teen Patti', false),
                ('bounty_football', 'Bounty Football', false),
              ])
                ChoiceChip(
                  label: Text(item.$3 ? item.$2 : '${item.$2} · Coming soon'),
                  selected: game == item.$1,
                  onSelected: busy || !item.$3
                      ? null
                      : (_) => setState(() {
                          game = item.$1;
                          result = null;
                          _key = null;
                          _request = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    game == 'fruit_wheel' ? 'Fruit Wheel' : 'Fruit Party',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (game == 'fruit_wheel')
                    segments.when(
                      loading: () => const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => TextButton(
                        onPressed: () => ref.invalidate(wheelSegmentsProvider),
                        child: const Text('Reload wheel'),
                      ),
                      data: (items) => SizedBox(
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _angle,
                              builder: (_, __) => Transform.rotate(
                                angle: _angle.value,
                                child: CustomPaint(
                                  size: const Size(230, 230),
                                  painter: _WheelPainter(items),
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 0,
                              child: Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 38,
                                color: Color(0xFF176B4C),
                              ),
                            ),
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.casino_outlined,
                                color: Color(0xFF176B4C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _PartyGrid(
                      grid: (outcome?['grid'] as List?)
                          ?.map((s) => s.toString())
                          .toList(),
                      busy: busy,
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Coins only. Every result and payout is settled by the server.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bet,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bet (coins)',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            widget.roomId == null ||
                            (game == 'fruit_wheel' && !segments.hasValue)
                        ? null
                        : _play,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      busy
                          ? 'Settling…'
                          : _key == null
                          ? 'Play'
                          : 'Retry round',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      'Round settled',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Bet ${r['bet'] ?? r['bet_amount'] ?? _lastBet} • Payout $payout coins',
                    ),
                    if (game == 'fruit_wheel')
                      Text(
                        '${outcome?['symbol'] ?? '—'} • ${outcome?['multiplier'] ?? 0}×',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartyGrid extends StatelessWidget {
  final List<String>? grid;
  final bool busy;
  const _PartyGrid({this.grid, required this.busy});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    child: busy
        ? const SizedBox(
            key: ValueKey('pending'),
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            key: ValueKey(grid?.join() ?? 'empty'),
            children: [
              for (var row = 0; row < 5; row++)
                Row(
                  children: [
                    for (var col = 0; col < 5; col++)
                      Expanded(
                        child: Container(
                          height: 48,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F8F3),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: grid != null && grid!.length == 25
                                ? _Symbol(grid![row * 5 + col])
                                : const Icon(
                                    Icons.remove,
                                    color: Color(0xFFBBCBC1),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
  );
}

class _Symbol extends StatelessWidget {
  final String symbol;
  const _Symbol(this.symbol);
  @override
  Widget build(BuildContext context) {
    final icon = switch (symbol) {
      'bell' => Icons.notifications_outlined,
      'gem' => Icons.diamond_outlined,
      'watermelon' => Icons.circle,
      'lemon' => Icons.egg_outlined,
      'grape' => Icons.bubble_chart,
      'orange' => Icons.circle_outlined,
      'plum' => Icons.spa_outlined,
      _ => null,
    };
    return Tooltip(
      message: symbol,
      child: icon == null
          ? Text(symbol, style: const TextStyle(fontWeight: FontWeight.w800))
          : Icon(
              icon,
              color: switch (symbol) {
                'watermelon' => const Color(0xFFEF6B70),
                'lemon' => const Color(0xFFB69A21),
                'orange' => const Color(0xFFDA8B36),
                'grape' || 'plum' => const Color(0xFF8A6AAF),
                _ => const Color(0xFF339B76),
              },
            ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  _WheelPainter(this.segments);
  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2),
        radius = size.width / 2;
    final sweep = 2 * pi / segments.length;
    for (var i = 0; i < segments.length; i++) {
      final symbol = segments[i]['symbol']?.toString() ?? '';
      final start = -pi / 2 + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..color = symbol == '77'
              ? const Color(0xFFDBEED2)
              : symbol == 'lemon'
              ? const Color(0xFFFFF4CE)
              : const Color(0xFFFFE0E0),
      );
      canvas.drawLine(
        center,
        center + Offset(cos(start), sin(start)) * radius,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
      final label = symbol == 'watermelon'
          ? 'W'
          : symbol == 'lemon'
          ? 'L'
          : symbol;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF334D40),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final point =
          center +
          Offset(cos(start + sweep / 2), sin(start + sweep / 2)) *
              (radius * .78);
      painter.paint(
        canvas,
        point - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
