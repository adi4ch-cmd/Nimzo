import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';

void main() {
  testWidgets(
      'animated ID plate fills the identity label instead of shrinking to a tiny card',
      (tester) async {
    const media = CosmeticMedia(
        'nimzo-drive-gold-id-plate',
        'ID Frame',
        'Gold ID Plate',
        'assets/drive_catalog/95742d9e8ceb2bea1c32927a222f84839d7129998d75212711f52699c4f919fe.svga',
        CosmeticMediaKind.svga);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          storeVisualEquipmentProvider('fixture-user')
              .overrideWith((ref) async => {'ID Frame': media})
        ],
        child: const MaterialApp(
            home: Center(
                child: SizedBox(
                    width: 180,
                    height: 32,
                    child: EquippedCosmetic(
                        userId: 'fixture-user',
                        category: 'ID Frame',
                        child: Text('ID: 100005')))))));
    for (var attempt = 0;
        attempt < 40 && find.byType(SVGAImage).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.text('ID: 100005'), findsOneWidget);
    expect(find.byType(SVGAImage), findsOneWidget);
    expect(tester.widget<SVGAImage>(find.byType(SVGAImage)).fit, BoxFit.fill);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
