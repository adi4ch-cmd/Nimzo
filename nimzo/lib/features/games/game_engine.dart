import 'dart:math';

/// Fruit Party 5x5. Play-money only: no cash-out, no real-money payout.
/// In production the round result comes from the server; this engine is the
/// client-side model and a deterministic test double.
enum Fruit { apple, cherry, lemon, grape, melon }

class GameState {
  final List<List<Fruit>> board;
  final int score;
  const GameState(this.board, this.score);
}

class GameEngine {
  static const size = 5;
  final Random _rng;
  GameEngine([int? seed]) : _rng = Random(seed);

  GameState newRound() => GameState(
      List.generate(size, (_) => List.generate(size, (_) => Fruit.values[_rng.nextInt(Fruit.values.length)])),
      0);

  /// Score = size of the largest connected same-fruit cluster.
  int score(List<List<Fruit>> b) {
    final seen = List.generate(size, (_) => List.filled(size, false));
    var best = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (seen[r][c]) continue;
        var n = 0;
        final st = <List<int>>[[r, c]];
        seen[r][c] = true;
        while (st.isNotEmpty) {
          final p = st.removeLast();
          final y = p[0], x = p[1];
          n++;
          for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            final ny = y + d[0], nx = x + d[1];
            if (ny < 0 || nx < 0 || ny >= size || nx >= size || seen[ny][nx] || b[ny][nx] != b[y][x]) continue;
            seen[ny][nx] = true;
            st.add([ny, nx]);
          }
        }
        best = max(best, n);
      }
    }
    return best;
  }
}
