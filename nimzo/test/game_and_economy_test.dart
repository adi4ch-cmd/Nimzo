import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_engine.dart';

// Mirrors the SQL split in send_gift (integer floor). The real check runs in Postgres.
List<int> split(int total) => [(total * 45) ~/ 100, (total * 5) ~/ 100];

void main() {
  test('economy: 100000 -> 45000 diamonds + 5000 owner coins', () {
    expect(split(100000), [45000, 5000]);
  });
  test('game board is 5x5 and score within bounds', () {
    final e = GameEngine(1);
    final s = e.newRound();
    expect(s.board.length, 5);
    expect(s.board.every((r) => r.length == 5), isTrue);
    expect(e.score(s.board), inInclusiveRange(1, 25));
  });
}
