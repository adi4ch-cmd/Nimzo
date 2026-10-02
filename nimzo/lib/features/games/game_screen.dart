import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'game_engine.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _S();
}

class _S extends State<GameScreen> {
  final _engine = GameEngine();
  late GameState _s = _engine.newRound();
  static const _icons = {
    Fruit.apple: Icons.apple,
    Fruit.cherry: Icons.circle,
    Fruit.lemon: Icons.brightness_1_outlined,
    Fruit.grape: Icons.blur_on,
    Fruit.melon: Icons.donut_large,
  };

  void _play() {
    final s = _engine.newRound();
    setState(() => _s = GameState(s.board, _engine.score(s.board)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fruit Party 5x5')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('Best cluster: ${_s.score}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 5, mainAxisSpacing: 6, crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final row in _s.board)
                    for (final f in row)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                            color: NimzoColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: NimzoColors.border)),
                        child: Icon(_icons[f], color: NimzoColors.primaryDark),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _play, child: const Text('New round')),
          ]),
        ),
      );
}
