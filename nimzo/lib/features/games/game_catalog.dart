class NimzoGame {
  final String slug, title;
  final int artwork;
  final bool serverEnabled;
  const NimzoGame(
    this.slug,
    this.title,
    this.artwork, {
    this.serverEnabled = false,
  });
}

abstract final class NimzoRoomGames {
  static const approved = [
    NimzoGame('fruit_party_jackpot', 'Fruit Party Jackpot', 0),
    NimzoGame('grady_lion', 'Grady Lion', 1),
    NimzoGame('bigetar', 'Bigetar', 2),
    NimzoGame('slot', 'Slot', 3),
    NimzoGame('teen_patti', 'Teen Patti', 4),
    NimzoGame('lucky_wheel_77', 'Lucky Wheel 77', 5),
    NimzoGame('bounty_football', 'Bounty Football', 6),
  ];
  // Existing backend RPC contracts are retained for callers; the approved catalog does not silently substitute these games.
  static const all = [
    ...approved,
    NimzoGame('fruit_party', 'Fruit Party', 0, serverEnabled: true),
    NimzoGame('fruit_wheel', 'Fruit Wheel', 5, serverEnabled: true),
  ];
  static bool canPlay(String slug) =>
      all.any((g) => g.slug == slug && g.serverEnabled);
}
