import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets('legacy static art is not advertised as a replayable animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: NimzoStoreFullPreview(
      item: NimzoCosmeticItem(
          id: 'nimzo-original-rides-golden-stars',
          category: 'Rides',
          name: 'Golden Stars',
          variant: 0,
          coinPrice: 0),
      owned: false,
      equipped: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Replay full preview'), findsNothing);
    expect(find.textContaining('Original NIMZO design'), findsWidgets);
  });
  testWidgets(
      'real static image identifies its format without animation promises',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: NimzoStoreFullPreview(
      item: NimzoCosmeticItem(
          id: 'nimzo-media-frame-gold-circle',
          category: 'Avatar Frame',
          name: 'Gold Circle',
          variant: 0,
          coinPrice: 0),
      owned: false,
      equipped: false,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Static artwork'), findsOneWidget);
    expect(find.text('View artwork again'), findsOneWidget);
    expect(find.text('Replay animation'), findsNothing);
  });
}
