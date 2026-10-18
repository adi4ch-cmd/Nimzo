import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('owner-approved Lucky 77 HTML5 board is bundled and matches bet rules',
      () async {
    final html =
        await rootBundle.loadString('assets/games/lucky77_room_demo.html');
    expect(html, contains('✨ LUCKY 77'));
    expect(html, contains('const sectors=[0,2,0,2,0,2,0,1]'));
    expect(html, contains('data-bet="0"'));
    expect(html, contains('data-bet="1"'));
    expect(html, contains('data-bet="2"'));
    for (final amount in [
      5000,
      10000,
      50000,
      300000,
      500000,
      1000000,
    ]) {
      expect(html, contains('data-amount="$amount"'));
    }

    // Two 2x outcomes may not be combined, including repeat wagers.
    expect(html, contains('if(index===0&&proposed[2]>0)return false'));
    expect(html, contains('if(index===2&&proposed[0]>0)return false'));
    expect(html, contains('if(source[0]>0&&source[2]>0)'));
    expect(html, contains("\$('#repeatBtn').onclick"));
    expect(html, contains('if(autoRepeat&&previousBets.some(Boolean))'));

    // Native commands are minimized and expanded via a tightly scoped bridge.
    expect(html, contains('nimzo-embedded'));
    expect(html, contains("window.NimzoGameBridge.postMessage('minimize')"));
    expect(html, contains("window.NimzoGameBridge.postMessage('expand')"));
    expect(html, isNot(contains('supabase.co')));
    expect(html, isNot(contains('p_bet_amount')));
  });

  test('Lucky 77 replaces the first incorrect game label, not backend wagers',
      () {
    expect(NimzoRoomGames.approved.first.slug, 'lucky_77');
    expect(NimzoRoomGames.approved.first.title, 'Lucky 77');
    expect(NimzoRoomGames.approved.first.artwork, 0);
    expect(NimzoRoomGames.canPlay('lucky_77'), isFalse);
    expect(
      NimzoRoomGames.all.where((game) => game.title == 'Lucky 77'),
      hasLength(1),
    );
  });
}
