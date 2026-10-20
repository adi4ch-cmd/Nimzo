import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/licensed_media_gallery.dart';

void main() {
  test('all 26 original media preserve actual source paths and types', () {
    expect(licensedStoreMedia.length, 26);
    expect(licensedStoreMedia.map((m) => m.assetPath).toSet().length, 26);
    expect(licensedStoreMedia.where((m) => m.animated).length, 1);
    expect(licensedStoreMedia.every((m) =>
      m.assetPath.startsWith('assets/licensed_tana_vani/')), isTrue);
  });

  testWidgets('original static media opens full preview without purchase controls', (tester) async {
    // NIMZO is a phone-width app; a desktop-width grid has taller tiles.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LicensedStoreGallery()));
    await tester.pump();
    expect(find.byKey(const ValueKey('licensed-media-grid')), findsOneWidget);
    expect(find.textContaining('26 original imported media files'), findsOneWidget);
    await tester.tap(find.text('Love Room Theme'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('licensed-media-full-preview')), findsOneWidget);
    expect(find.textContaining('No coins are charged'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
  });
}
