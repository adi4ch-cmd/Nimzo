import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/vip/vip_screen.dart';
import 'package:nimzo/features/vip/vip_repository.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('final membership and room overlay visual previews',
      (tester) async {
    for (final font in [
      ('Roboto', 'test/fonts/Roboto-Regular.ttf'),
      ('Cinzel', 'assets/reference/fonts/Cinzel.ttf'),
      ('Poppins', 'assets/reference/fonts/Poppins-Regular.ttf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(Future.value(
                ByteData.sublistView(File(font.$2).readAsBytesSync()))))
          .load();
    }
    await (FontLoader('packages/lucide_flutter/LucideIcons')
          ..addFont(
              rootBundle.load('packages/lucide_flutter/assets/lucide.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final preview in <(String, Widget)>[
      ('vip_final', const VipScreen()),
      ('svip_final', const VipScreen(svip: true)),
      (
        'treasure_final',
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: TreasureSheet()))
      ),
      (
        'crystal_final',
        const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: CrystalSheet()))
      ),
    ]) {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            vipStatusProvider
                .overrideWith((_) async => {'vip_level': 0, 'svip_level': 0}),
            walletProvider.overrideWith((_) async => (coins: 0, diamonds: 0))
          ],
          child: MaterialApp(
              theme: AppTheme.light(),
              home: RepaintBoundary(
                  key: const ValueKey('preview'), child: preview.$2))));
      await tester.pump();
      if (preview.$1 == 'vip_final' || preview.$1 == 'svip_final') {
        final context = tester.element(find.byKey(const ValueKey('preview')));
        await tester.runAsync(() async {
          for (final family in ['vip', 'svip']) {
            for (var i = 0; i < 10; i++) {
              final asset = family == 'svip'
                  ? 'assets/membership/svip/svip_medal${i + 1}.webp'
                  : 'assets/reference/vip/$i.jpg';
              await precacheImage(AssetImage(asset), context);
            }
          }
        });
      }
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byKey(const ValueKey('preview')),
          matchesGoldenFile('goldens/${preview.$1}.png'));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
