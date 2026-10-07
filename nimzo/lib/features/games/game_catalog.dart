/// Nimzo room games. Only the legacy two have verified RPC wiring.
/// Never enable a coin game solely because its artwork or title exists.
class NimzoRoomGame {
  final String slug;
  final String title;
  final bool serverEnabled;

  const NimzoRoomGame(this.slug, this.title, {this.serverEnabled = false});
}

class NimzoRoomGames {
  NimzoRoomGames._();

  static const List<NimzoRoomGame> all = [
    NimzoRoomGame('fruit_party', 'Fruit Party', serverEnabled: true),
    NimzoRoomGame('fruit_wheel', 'Fruit Wheel', serverEnabled: true),
    NimzoRoomGame('fruit_party_jackpot', 'Fruit Party Jackpot'),
    NimzoRoomGame('grady_lion', 'Grady Lion'),
    NimzoRoomGame('bigetar', 'Bigetar'),
    NimzoRoomGame('slot', 'Slot'),
    NimzoRoomGame('teen_patti', 'Teen Patti'),
    NimzoRoomGame('lucky_wheel_77', 'Lucky Wheel 77'),
    NimzoRoomGame('bounty_football', 'Bounty Football'),
  ];

  static bool canPlay(String slug) =>
      all.any((game) => game.slug == slug && game.serverEnabled);
}
