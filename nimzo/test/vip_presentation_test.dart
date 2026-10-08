import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/vip_screen.dart';
import 'package:nimzo/features/vip/vip_repository.dart';
import 'package:nimzo/features/vip/vip_progress.dart';

void main() {
  Future<void> mount(WidgetTester tester, {bool svip = false}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          membershipNameProvider.overrideWith((_) async => 'Alex'),
          vipStatusProvider
              .overrideWith((_) async => {'vip_level': 2, 'svip_level': 3}),
          svipProgressProvider.overrideWith(
              (_) async => SvipProgress(cycleCents: 5000, thresholds: {
                    1: 5000,
                    2: 20000,
                    3: 50000,
                    4: 100000,
                    5: 300000,
                    6: 1000000,
                    7: 3000000,
                    8: 7500000
                  })),
        ],
        child: MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: VipScreen(svip: svip)))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('tier selection previews artwork without changing active status',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('vip-tier-2')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('VIP 2 · Collection preview'), findsOneWidget);
    expect(find.text('Active · VIP 2'), findsOneWidget);
    expect(find.text('Preview VIP 2 · Purchase unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SVIP tier ten remains an honest preview with live progress',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, svip: true);
    await tester.drag(find.byType(ListView).last, const Offset(-850, 0));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('svip-tier-10')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('SVIP 10 · Collection preview'), findsOneWidget);
    expect(find.text('Active · SVIP 3'), findsOneWidget);
    expect(find.text('Configured tier'), findsNothing);
    expect(
        find.textContaining('tiers 9–10 are design previews'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 760.0, 1200.0]) {
    testWidgets('premium layouts fit width $width without overflow',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, svip: true);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });
  }
}
