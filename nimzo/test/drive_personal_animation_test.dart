import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_celebration_overlay.dart';
import 'package:nimzo/features/gifts/remote_gift_svga_overlay.dart';

void main() {
  testWidgets(
      'settled personal dynamic gift uses verified SVGA rather than thumbnail celebration',
      (tester) async {
    const publication = ApprovedMediaPublication(
        sha256Hex:
            '66c8c4fa8cfa9f238bed13b34e6bff6a8d26fa0dd9861350e0e4d308aaf1e8b6',
        byteLength: 412101,
        mimeType: 'application/x-svga',
        codec: 'svga');
    const media = GiftPlaybackMedia(
        url:
            'https://example.test/66c8c4fa8cfa9f238bed13b34e6bff6a8d26fa0dd9861350e0e4d308aaf1e8b6.svga',
        kind: 'svga',
        publication: publication);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showSettledPersonalGiftCelebration(context,
                        giftName: 'Magic Genie',
                        quantity: 1,
                        unitPrice: 15000,
                        media: media,
                        requiresAnimation: true),
                    child: const Text('Settled'))))));
    await tester.tap(find.text('Settled'));
    await tester.pump();
    expect(find.byType(RemoteGiftSvgaOverlay), findsOneWidget);
    expect(find.byType(NimzoGiftCelebration), findsNothing);
    final overlay = tester
        .widget<RemoteGiftSvgaOverlay>(find.byType(RemoteGiftSvgaOverlay));
    expect(overlay.source, media.url);
    expect(overlay.publication, same(publication));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'missing required personal animation never becomes a paid thumbnail effect',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showSettledPersonalGiftCelebration(context,
                        giftName: 'Magic Genie',
                        quantity: 1,
                        unitPrice: 15000,
                        requiresAnimation: true),
                    child: const Text('Settled'))))));
    await tester.tap(find.text('Settled'));
    await tester.pump();
    expect(find.byType(NimzoGiftCelebration), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
