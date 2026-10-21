import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';

void main() {
  testWidgets('Original CP Love Avatar SVGA fully decodes and generates its own PNG preview',
      (tester) async {
    final captureKey = GlobalKey();
    const media = CosmeticMedia(
      'nimzo-original-cp-love-avatar',
      'Avatar Frame',
      'CP Love Avatar',
      'assets/willchill_premium/room_fx/voice_room_cp_love_avatar.svga',
      CosmeticMediaKind.svga,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SizedBox(
            width: 240, height: 240,
            child: RepaintBoundary(
              key: captureKey,
              child: CosmeticMediaView(media: media, animate: false),
            ),
          ),
        ),
      ),
    ));

    for (var n = 0; n < 80 && find.byType(SVGAImage).evaluate().isEmpty; n++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(SVGAImage), findsOneWidget,
        reason: 'Do not publish animation that cannot actually decode');
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump();
    final boundary = captureKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    expect(bytes, isNotNull);
    final file = File('build/store_previews/cp_love_avatar.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    expect(await file.length(), greaterThan(1000),
        reason: 'Thumbnail must be captured from real animation, never a placeholder');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
