import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/constants/app_constants.dart';
import 'package:nimzo/features/games/game_catalog.dart';

void main() {
  test('NIMZO audio rooms retain exactly ten microphones', () {
    expect(AppConstants.micSeatCount, 10,
      reason: 'The user requires ten seats even when reference shows twelve.');
  });
  test('NIMZO OAuth callback remains bound to our own package', () {
    expect(AppConstants.oauthRedirect, 'io.nimzo.app://login-callback');
  });
  test('All seven requested game boards stay represented', () {
    final slugs = NimzoRoomGames.approved.map((g) => g.slug).toList();
    expect(slugs.toSet().length, slugs.length);
    expect(slugs, containsAll(<String>[
      'lucky_77',
      'grady_lion',
      'bigetar',
      'jackpot',
      'teen_patti',
      'lucky_wheel_77',
      'bounty_football',
    ]));
  });
  test('Unsettled game previews cannot masquerade as playable', () {
    for (final game in NimzoRoomGames.approved) {
      if (!game.serverEnabled) {
        expect(NimzoRoomGames.canPlay(game.slug), isFalse,
          reason: 'Server-side payouts must exist before real bets.');
      }
    }
  });
}
