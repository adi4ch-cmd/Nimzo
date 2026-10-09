import 'dart:math';

/// Non-financial board utility retained for existing contract tests. Never used to settle coin games.
class GameRound {
  final List<List<int>> board;
  const GameRound(this.board);
}

class GameEngine {
  final Random random;
  GameEngine(int seed) : random = Random(seed);
  GameRound newRound() => GameRound(
    List.generate(5, (_) => List.generate(5, (_) => random.nextInt(8))),
  );
  int score(List<List<int>> board) {
    final counts = <int, int>{};
    for (final row in board) {
      for (final symbol in row) {
        counts[symbol] = (counts[symbol] ?? 0) + 1;
      }
    }
    return counts.isEmpty ? 0 : counts.values.reduce(max);
  }
}
