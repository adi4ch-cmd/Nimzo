import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/games/game_screen.dart';
import 'package:nimzo/features/games/game_catalog.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'support/test_game_webview.dart';

void main() {
  late TestGameWebViewPlatform webviews;
  setUp(() => webviews = TestGameWebViewPlatform.install());
  testWidgets('approved boards and real empty home remain visually stable', (
    tester,
  ) async {
    final font = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('test/fonts/Roboto-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('packages/lucide_flutter/LucideIcons')
      ..addFont(rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'));
    await icons.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('home-scope'),
        overrides: [popularRoomsProvider(null).overrideWith((_) async => [])],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RepaintBoundary(
            key: ValueKey('preview'),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/home_empty.png'),
    );
    for (final slug in [
      'lucky_77',
      'grady_lion',
      'jackpot',
      'lucky_wheel_77',
      'bigetar',
      'teen_patti',
      'bounty_football',
    ]) {
      var minimized = 0;
      var expanded = 0;
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(slug),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RepaintBoundary(
              key: const ValueKey('preview'),
              child: GameScreen(
                slug: slug,
                roomId: 'room',
                onMinimize: ['lucky_77', 'grady_lion', 'jackpot'].contains(slug)
                    ? () => minimized++
                    : null,
                onExpand: ['lucky_77', 'grady_lion', 'jackpot'].contains(slug)
                    ? () => expanded++
                    : null,
              ),
            ),
          ),
        ),
      );
      if (['lucky_77', 'grady_lion', 'jackpot'].contains(slug)) {
        final asset = {
          'lucky_77': 'assets/games/lucky77_room_demo.html',
          'grady_lion': 'assets/games/grady_lion_auto.html',
          'jackpot': 'assets/games/jackpot_9lines_demo.html',
        }[slug]!;
        final controller = webviews.controllers.last;
        expect(controller.flutterAsset, asset);
        expect(controller.channels.keys, ['NimzoGameBridge']);
        expect(find.byType(WebViewWidget), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          await controller.requestNavigation('https://example.com/$asset'),
          NavigationDecision.prevent,
        );
        controller.sendBridgeMessage('wallet');
        controller.sendBridgeMessage('auth');
        controller.sendBridgeMessage('{"action":"minimize"}');
        expect((minimized, expanded), (0, 0));
        controller.sendBridgeMessage('minimize');
        controller.sendBridgeMessage('expand');
        expect((minimized, expanded), (1, 1));
        controller.finishPage();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        // Flutter cannot render native HTML. Its graphics are covered by the
        // browser/device harness; never golden the platform placeholder.
        continue;
      }
      final context = tester.element(find.byKey(const ValueKey('preview')));
      await tester.runAsync(() async {
        // pumpAndSettle does not wait for asynchronous image decoding. The
        // header is a separate asset family from the board and must be ready.
        final game = NimzoRoomGames.approved.singleWhere((g) => g.slug == slug);
        await precacheImage(
          AssetImage('assets/reference/game/${game.artwork}.jpg'),
          context,
        );
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('goldens/$slug.png'),
      );
    }
  });
}
