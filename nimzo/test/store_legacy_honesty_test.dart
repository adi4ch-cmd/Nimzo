import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets('legacy static art is not advertised as a replayable animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NimzoStoreFullPreview(
      item: NimzoCosmeticItem(id: 'nimzo-original-rides-golden-stars',
        category: 'Rides', name: 'Golden Stars', variant: 0, coinPrice: 0),
      owned: false, equipped: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Replay full preview'), findsNothing);
    expect(find.textContaining('Original NIMZO design'), findsWidgets);
  });
}
