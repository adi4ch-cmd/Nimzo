import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets(
      'Portrait 3 decodes its bundled SVGA instead of staying a placeholder',
      (tester) async {
    const portrait = NimzoCosmeticItem(
      id: 'nimzo-media-portrait-3',
      category: 'Avatar Frame',
      name: 'Portrait 3',
      variant: 0,
      coinPrice: 0,
    );
    await tester.pumpWidget(const MaterialApp(
        home: NimzoStoreFullPreview(
      item: portrait,
      owned: false,
      equipped: false,
    )));
    for (var attempt = 0;
        attempt < 40 && find.byType(SVGAImage).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(SVGAImage), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  const gold = NimzoCosmeticItem(
    id: 'nimzo-media-frame-gold-circle',
    category: 'Avatar Frame',
    name: 'Gold Circle',
    variant: 0,
    coinPrice: 0,
  );
  testWidgets('imported frame renders its real image in Store and Backpack',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nimzoStoreProvider.overrideWith((ref) async => NimzoStoreSnapshot(
            items: [gold],
            owned: {gold.id},
            equipped: {'Avatar Frame': gold.id}))
      ],
      child: const MaterialApp(home: NimzoLiveStore()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CosmeticMediaView), findsOneWidget);
    final media =
        tester.widget<CosmeticMediaView>(find.byType(CosmeticMediaView));
    expect(media.media.asset, endsWith('ic_avatar_frame_gold_circle.png'));
    expect(find.byTooltip('Preview premium media'), findsNothing);
    await tester.tap(find.text('Backpack'));
    await tester.pumpAndSettle();
    expect(find.byType(CosmeticMediaView), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full preview resolves the same item media', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: NimzoStoreFullPreview(
      item: gold,
      owned: false,
      equipped: false,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(CosmeticMediaView), findsOneWidget);
    expect(
        tester
            .widget<CosmeticMediaView>(find.byType(CosmeticMediaView))
            .media
            .id,
        gold.id);
    expect(tester.takeException(), isNull);
  });
}
