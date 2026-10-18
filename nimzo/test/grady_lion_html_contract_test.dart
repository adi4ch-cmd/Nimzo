import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved Grady Lion HTML game ships with timed automatic rounds',
      () async {
    final html = await rootBundle.loadString('assets/games/grady_lion_auto.html');
    expect(html, contains('GRADY LION'));
    expect(html, contains('const CHIPS=[5000,10000,50000,300000,1000000]'));
    expect(html, contains('const BET_SECONDS=20, RESULT_MS=2700'));
    expect(html, isNot(contains('const BET_SECONDS=12')));
    expect(html, contains('if(bets[i]===0&&selected()>=6)'));
    expect(html, contains('bets[i]+=chip;refresh()'));
    expect(html, contains("roundTimer=setInterval(tick,1000)"));
    expect(html, contains('if(seconds===0){startDraw();return;}'));
    expect(html, contains('bets=auto?[...previous]:Array(OPTIONS.length).fill(0)'));
    expect(html, contains('function toggleAuto()'));
    expect(html, contains('const embedded=!!(window.NimzoGameBridge'));
    expect(html, contains("window.NimzoGameBridge.postMessage('minimize')"));
    expect(html, contains("window.NimzoGameBridge.postMessage('expand')"));
    expect(html, isNot(contains('supabase.co')));
    // The result and history use the same original art as the playing board.
    expect(html, contains('function boardSymbol(i)'));
    expect(html, contains(r"getComputedStyle($('board')).backgroundImage"));
    expect(html, contains(r"$('winnerIcon').innerHTML=boardSymbol(i)"));
    expect(html, contains('BOARD_ART_CENTERS'));
    expect(html, contains('background-size:588.24% 588.24%'));
    expect(html, isNot(contains('<div class="lionface">🦁</div>')));
    // Reference video: #2 at left, #1 in center, #3 at right.
    expect(html, contains('This Round Ranking'));
    expect(html, contains('function renderRoundLeaders()'));
    expect(html, contains('const ranks=[1,0,2]'));
    expect(html, contains("img.alt=winner.name+' avatar'"));
    expect(html, contains('DEMO — sample winners, not real users'));
    expect(html, contains('setRoundWinnersForPreview'));
    expect(html, isNot(contains('p_bet_amount')));
    expect(html, isNot(contains("spinBtn').onclick")));
  });

  test('Grady Lion retains its catalog identity and never settles real bets',
      () {
    final matching = NimzoRoomGames.approved.where(
      (g) => g.slug == 'grady_lion',
    ).toList();
    expect(matching, hasLength(1));
    expect(matching.single.title, 'Grady Lion');
    expect(matching.single.artwork, 1);
    expect(matching.single.serverEnabled, isFalse);
    expect(NimzoRoomGames.canPlay('grady_lion'), isFalse);
    expect(NimzoRoomGames.approved.first.title, 'Lucky 77');
  });
}
