import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/test_game_webview.dart';

void main() {
  late TestGameWebViewPlatform platform;
  setUp(() => platform = TestGameWebViewPlatform.install());

  const games = {
    'lucky_77': ('assets/games/lucky77_room_demo.html', 'Lucky 77'),
    'grady_lion': ('assets/games/grady_lion_auto.html', 'Grady Lion'),
    'jackpot': ('assets/games/jackpot_9lines_demo.html', 'Jackpot'),
  };

  for (final game in games.entries) {
    testWidgets('${game.key} hands off its bundled HTML and restricts bridge',
        (tester) async {
      var minimized = 0;
      var expanded = 0;
      var closed = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: GameScreen(
              slug: game.key,
              roomId: 'room',
              onMinimize: () => minimized++,
              onExpand: () => expanded++,
              onClose: () => closed++,
              roomControls: const Text('Native room controls'),
            ),
          ),
        ),
      );
      final controller = platform.controllers.single;
      expect(controller.flutterAsset, game.value.$1);
      expect(
        await tester.runAsync(() => rootBundle.loadString(game.value.$1)),
        contains('<html'),
      );
      expect(controller.javaScriptMode, JavaScriptMode.unrestricted);
      expect(controller.backgroundColor, const Color(0xff240444));
      expect(controller.channels.keys, ['NimzoGameBridge']);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byKey(const ValueKey('native-game-webview-test-boundary')),
          findsOneWidget);
      expect(find.text('Native room controls'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(await controller.requestNavigation(controller.localAssetUrl),
          NavigationDecision.navigate);
      expect(
          await controller.requestNavigation(
              'https://appassets.androidplatform.net/${game.value.$1}'),
          NavigationDecision.navigate);
      for (final url in [
        'https://example.com/${game.value.$1}',
        'https://example.com/',
        'file:///android_asset/flutter_assets/assets/games/other.html',
        'javascript:alert(1)',
      ]) {
        expect(
            await controller.requestNavigation(url), NavigationDecision.prevent,
            reason: url);
      }
      for (final message in [
        'wallet',
        'debit',
        'auth',
        'room',
        'close',
        '{"action":"minimize"}',
        'Minimize',
        '',
      ]) {
        controller.sendBridgeMessage(message);
      }
      expect((minimized, expanded, closed), (0, 0, 0));
      controller.sendBridgeMessage('minimize');
      controller.sendBridgeMessage('expand');
      expect((minimized, expanded, closed), (1, 1, 0));
      controller.finishPage();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${game.key} shows a native main-frame load failure',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: GameScreen(slug: game.key, roomId: 'room')),
      ));
      final controller = platform.controllers.single;
      controller.failMainFrame(isForMainFrame: false);
      await tester.pump();
      expect(find.text('${game.value.$2} could not load.'), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
      controller.failMainFrame();
      await tester.pump();
      expect(find.text('${game.value.$2} could not load.'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
