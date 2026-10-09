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

void main() {
  testWidgets('approved boards and real empty home remain visually stable',
      (tester) async {
    final font = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(
          File('test/fonts/Roboto-Regular.ttf').readAsBytesSync())));
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
    await tester.pumpWidget(ProviderScope(
        key: const ValueKey('home-scope'),
        overrides: [popularRoomsProvider(null).overrideWith((_) async => [])],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: const RepaintBoundary(
                key: ValueKey('preview'), child: HomeScreen()))));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const ValueKey('preview')),
        matchesGoldenFile('goldens/home_empty.png'));
    for (final slug in [
      'fruit_party_jackpot',
      'grady_lion',
      'slot',
      'lucky_wheel_77'
    ]) {
      await tester.pumpWidget(ProviderScope(
          key: ValueKey(slug),
          child: MaterialApp(
              theme: AppTheme.light(),
              home: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: GameScreen(slug: slug, roomId: 'room')))));
      final context = tester.element(find.byKey(const ValueKey('preview')));
      final group = slug == 'grady_lion'
          ? 'grady'
          : slug == 'slot'
              ? 'slot'
              : 'fruit';
      await tester.runAsync(() async {
        // pumpAndSettle does not wait for asynchronous image decoding. The
        // header is a separate asset family from the board and must be ready.
        final game = NimzoRoomGames.approved.singleWhere((g) => g.slug == slug);
        await precacheImage(
            AssetImage('assets/reference/game/${game.artwork}.jpg'), context);
        if (slug != 'lucky_wheel_77') {
          for (var i = 0;
              i <
                  (group == 'grady'
                      ? 10
                      : group == 'slot'
                          ? 12
                          : 8);
              i++) {
            await precacheImage(
                AssetImage('assets/reference/$group/$i.jpg'), context);
          }
        }
      });
      await tester.pumpAndSettle();
      await expectLater(find.byKey(const ValueKey('preview')),
          matchesGoldenFile('goldens/$slug.png'));
    }
  });
}
