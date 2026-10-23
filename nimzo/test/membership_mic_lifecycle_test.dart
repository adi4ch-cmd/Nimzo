import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';

void main() {
  testWidgets(
      'real original mic wave pauses in background and resumes without leaking player',
      (tester) async {
    final boundary = GlobalKey();
    Future<String> pixels() async => (await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: .5);
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final hash = sha256.convert(bytes.buffer.asUint8List()).toString();
          image.dispose();
          return hash;
        }))!;
    final art = MembershipPackInventory.forTier('vip', 5)[5];
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                    width: 180,
                    height: 180,
                    child: CosmeticMediaView(
                        media: CosmeticMedia('mic-test', 'Mic Wave', 'VIP5 mic',
                            art.path!, CosmeticMediaKind.svga)))))));
    for (var i = 0; i < 80 && find.byType(SVGAImage).evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(SVGAImage), findsOneWidget);
    final first = await pixels();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await pixels(), isNot(first));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = await pixels();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await pixels(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await pixels(), isNot(paused));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
