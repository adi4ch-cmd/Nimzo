import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nine-line Jackpot stays fully local until UI and wagering approval',
      () async {
    final html = await rootBundle.loadString('assets/games/jackpot_9lines_demo.html');
    expect(html, contains('<title>NIMZO · Jackpot Practice</title>'));
    expect(html, contains('const patterns=[['));
    expect(html, contains('lines<9'));
    expect(html, contains('lines>1'));
    expect(html, contains('function totalBet(){return lines*perLine}'));
    for (final chip in [500, 5000, 50000, 500000, 1000000]) {
      expect(html, contains(chip.toString()));
    }
    expect(html, contains('window.NimzoGameBridge'));
    expect(html, contains('nimzo-embedded'));
    expect(html, contains('contributionRate:0.01'));
    expect(html, contains('jackpotAward=jackpotPool'));
    expect(html, contains('jackpotPool=JACKPOT_CONFIG.seedAmount'));
    expect(html, isNot(contains('supabase.co')));
    expect(html, isNot(contains('p_bet_amount')));
    expect(NimzoRoomGames.canPlay('jackpot'), false);
  });

  test('all three HTML5 games stay server-disabled', () {
    for (final slug in ['lucky_77', 'grady_lion', 'jackpot']) {
      expect(NimzoRoomGames.approved.where((g) => g.slug == slug),
          hasLength(1));
      expect(NimzoRoomGames.canPlay(slug), false);
    }
    expect(NimzoRoomGames.canPlay('fruit_party'), true);
  });
}
