import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/gifts/gift_svga_overlay.dart';

void main() {
  test('all twenty active catalog names resolve to their own bundled image',
      () async {
    final originals = [
      'Kiss','Coffee','Cat','Birthday Cake','Teddy Bear','Gift Box',
      'Panda','Diamond Ring','Golden Palace','Private Jet',
      'Luxury Yacht','Dragon','Golden Dragon','Phoenix',
    ];
    final licensed = [
      'Rose','Heart','Crown','Diamond','Rocket','Sports Car',
    ];
    final paths = <String>{};
    for (final name in [...originals, ...licensed]) {
      final path = originalNimzoGiftArtwork(name) ?? freeGiftArtwork(name);
      expect(path, isNotNull, reason: name);
      expect(paths.add(path!), isTrue, reason: 'Gift icons must not repeat');
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(100),
          reason: 'Bundled gallery art missing for $name');
    }
    expect(paths, hasLength(20));
  });

  test('only actually bundled original SVGA gifts are marked animated', () {
    expect(freeGiftAnimationForName('Rocket'), isNotNull);
    expect(freeGiftAnimationForName('Sports Car'), isNotNull);
    for (final name in ['Dragon', 'Phoenix', 'Golden Palace', 'Cat', 'Rose']) {
      expect(freeGiftAnimationForName(name), isNull,
          reason: 'Never promise an unavailable per-gift video');
    }
  });

  testWidgets('live named gift displays its matching real catalog art',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(height: 100, width: 100,
          child: GiftArtwork(name: 'Sports Car')),
    )));
    await tester.pump();
    final icon = tester.widget<Image>(find.byType(Image));
    expect((icon.image as AssetImage).assetName,
        'assets/gifts/free/sports_car.png');
    expect(tester.takeException(), isNull);
  });
}
