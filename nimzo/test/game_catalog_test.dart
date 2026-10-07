import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';

void main() {
  test('approved seven games are represented without fake playable engines', () {
    const approved = [
      'Fruit Party Jackpot', 'Grady Lion', 'Bigetar', 'Slot',
      'Teen Patti', 'Lucky Wheel 77', 'Bounty Football',
    ];
    for (final name in approved) {
      final matching = NimzoRoomGames.all.where((g) => g.title == name).toList();
      expect(matching, hasLength(1));
      expect(matching.single.serverEnabled, isFalse);
      expect(NimzoRoomGames.canPlay(matching.single.slug), isFalse);
    }
  });

  test('only existing legacy RPC-backed games are enabled', () {
    final enabled = NimzoRoomGames.all
        .where((g) => g.serverEnabled)
        .map((g) => g.slug)
        .toSet();
    expect(enabled, {'fruit_party', 'fruit_wheel'});
    expect(NimzoRoomGames.canPlay('unknown'), isFalse);
    expect(NimzoRoomGames.all.map((g) => g.slug).toSet(),
        hasLength(NimzoRoomGames.all.length));
  });
}
