import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/widgets/art/nimzo_identity_art.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  testWidgets('gold frame preview renders the imported image rather than generated art', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NimzoStoreFullPreview(
      item: NimzoCosmeticItem(id: 'nimzo-media-frame-gold-circle', category: 'Avatar Frame', name: 'Gold Circle', variant: 0, coinPrice: 0),
      owned: false, equipped: false,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(NimzoIdentityArt), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/premium_store/willchill/ic_avatar_frame_gold_circle.png'), findsOneWidget);
  });
}
