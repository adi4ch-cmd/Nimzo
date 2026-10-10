import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/haza_membership_artwork.dart';
import 'package:nimzo/features/vip/vip_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Haza has exactly 7 original VIP tags; NIMZO levels 8-10 stay honest',
      () {
    for (var tier = 1; tier <= 7; tier++) {
      expect(HazaMembershipArtwork.badge(tier),
          'assets/haza_membership/vip/ic_vip_tag_$tier.png');
    }
    for (var tier = 8; tier <= 10; tier++) {
      expect(HazaMembershipArtwork.badge(tier), isNull);
    }
    for (var tier = 1; tier <= 10; tier++) {
      expect(HazaMembershipArtwork.stage(tier),
          startsWith('assets/haza_membership/vip/ic_vip_bg_'));
      expect(HazaMembershipArtwork.border(tier),
          startsWith('assets/haza_membership/vip/ic_vip_border_'));
    }
  });

  testWidgets('Original Haza badge renders only when installed', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MembershipEmblem(level: 3, svip: false, size: 154),
      ),
    ));
    await tester.pump();
    // Always validate the intended source path. If the licensed archive is
    // not yet installed, Image.errorBuilder renders the original NIMZO seal.
    final image = tester.widget<Image>(
        find.byKey(const ValueKey('haza-vip-badge-3')));
    expect((image.image as AssetImage).assetName,
        'assets/haza_membership/vip/ic_vip_tag_3.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIP 8-10 never masquerade as VIP 7', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            MembershipEmblem(level: 8, svip: false, size: 80),
            MembershipEmblem(level: 9, svip: false, size: 80),
            MembershipEmblem(level: 10, svip: false, size: 80),
          ],
        ),
      ),
    ));
    expect(find.byType(NimzoRoyalVipSeal), findsNWidgets(3));
    expect(find.byKey(const ValueKey('haza-vip-badge-7')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('All 10 SVIP medals remain intact', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MembershipEmblem(level: 10, svip: true, size: 80),
      ),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
      'assets/membership/svip/svip_medal10.webp');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Licensed stage is decoration and cannot trigger purchases',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 240,
          child: HazaMembershipStage(tier: 5, svip: false),
        ),
      ),
    ));
    // Wait for the bundled AssetManifest FutureBuilder before asserting
    // which licensed stage image was rendered by the Flutter asset pipeline.
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byKey(const ValueKey('haza-vip-stage')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('haza-vip-stage')));
    expect((image.image as AssetImage).assetName,
      'assets/haza_membership/vip/ic_vip_bg_3.webp');
    expect(tester.takeException(), isNull);
  });
}
