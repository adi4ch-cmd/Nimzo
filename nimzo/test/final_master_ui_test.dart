import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/vip_screen.dart';
import 'package:nimzo/features/vip/vip_repository.dart';
import 'package:nimzo/features/games/game_screen.dart';

void main() {
  testWidgets('VIP selector exposes tier-specific looks without purchasing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vipStatusProvider.overrideWith(
            (_) async => {'vip_level': 0, 'svip_level': 0},
          ),
          vipDailyRewardsProvider.overrideWith((_) async => []),
        ],
        child: const MaterialApp(home: VipScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('VIP 5'), findsWidgets);
    expect(find.text('No active VIP membership'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('vip-tier-3')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('vip-tier-3')));
    await tester.pump();
    expect(find.text('Preview VIP 3 · Purchase unavailable'), findsOneWidget);
    expect(find.text('VIP 3 · Collection preview'), findsOneWidget);
    await tester.tap(find.text('Preview VIP 3 · Purchase unavailable'));
    await tester.pump();
    expect(find.text('VIP purchase is unavailable.'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VipScreen)),
    );
    expect(container.read(vipStatusProvider).valueOrNull?['vip_level'], 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Bigetar renders final multipliers and marque markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameScreen(slug: 'bigetar', roomId: 'room'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BM'), findsOneWidget);
    expect(find.text('66x'), findsOneWidget);
    expect(find.text('Results unavailable'), findsOneWidget);
  });
}
