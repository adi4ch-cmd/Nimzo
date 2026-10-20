import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets('original Store item opens as full preview with replay and no charges',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NimzoStoreFullPreview(
        item: NimzoCosmeticItem(
          id: 'nimzo-original-rides-golden-stars',
          category: 'Rides',
          name: 'Golden Stars',
          variant: 0,
          coinPrice: 0,
        ),
        owned: false,
        equipped: false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nimzo-store-full-preview')),
        findsOneWidget);
    expect(find.text('Golden Stars'), findsWidgets);
    expect(find.text('Preview only — not yet owned'), findsOneWidget);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.textContaining('Coins deducted'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nimzo-preview-replay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('detail Collect action returns to live Store and invokes RPC path',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    var collected = false;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: TextButton(
          onPressed: () => navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => NimzoStoreFullPreview(
                item: const NimzoCosmeticItem(
                  id: 'nimzo-original-rides-golden-stars',
                  category: 'Rides',
                  name: 'Golden Stars',
                  variant: 0,
                  coinPrice: 0,
                ),
                owned: false,
                equipped: false,
                onAction: () => collected = true,
              ),
            ),
          ),
          child: const Text('Open design'),
        ),
      ),
    ));
    await tester.tap(find.text('Open design'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nimzo-preview-apply')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nimzo-preview-apply')));
    await tester.pumpAndSettle();
    expect(collected, isTrue);
    expect(find.text('Open design'), findsOneWidget);
  });

}
