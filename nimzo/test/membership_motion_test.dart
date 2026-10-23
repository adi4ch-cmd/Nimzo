import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/features/premium/membership_media_view.dart';

void main() {
  testWidgets('decorative membership hero animates and pauses with lifecycle',
      (tester) async {
    final manifest = jsonDecode((await tester.runAsync(() =>
        rootBundle.loadString('assets/membership/remix/manifest.json')))!);
    final row = (manifest['items'] as List).firstWhere(
        (r) => r['kind'] == 'svip' && r['tier'] == 10 && r['role'] == 'hero');
    final media = MembershipMedia(
        url: row['asset'],
        sha256: row['sha256'],
        bytes: row['bytes'],
        format: 'svga');
    var finished = 0;
    final boundary = GlobalKey();
    Future<String> hashFrame() async => (await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: .5);
          final bytes =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final hash = sha256.convert(bytes!.buffer.asUint8List()).toString();
          image.dispose();
          return hash;
        }))!;
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                    width: 240,
                    height: 240,
                    child: MembershipMediaView(
                        media: media, onFinished: () => finished++))))));
    for (var i = 0; i < 80 && find.byType(SVGAImage).evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    final first = await hashFrame();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await hashFrame(), isNot(first),
        reason: 'A decorative SVGA hero must actually animate');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = await hashFrame();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await hashFrame(), paused,
        reason: 'Backgrounded decorations must pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await hashFrame(), isNot(paused));
    expect(finished, 0,
        reason: 'Decorative loops do not emit entrance completion');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
