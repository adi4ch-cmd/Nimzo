import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/gifts/gift_svga_overlay.dart';

void main() {
  test('Only real, matching Rocket and Sports Car free SVGA effects are mapped',
      () {
    expect(freeGiftAnimationsById, hasLength(2));
    expect(
      freeGiftAnimationForId('99faac6c-933c-4c08-8026-08c39227751e'),
      'assets/gifts/free/rocket.svga',
    );
    expect(
      freeGiftAnimationForId('35e4c570-cb02-4466-ae86-d670b3fb05ab'),
      'assets/gifts/free/sports_car.svga',
    );
    expect(freeGiftAnimationForId('c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330'),
        isNull);
    expect(freeGiftAnimationForId(''), isNull);
    expect(freeGiftAnimationForName('Sports Car'),
        'assets/gifts/free/sports_car.svga');
    expect(freeGiftAnimationForName('Dragon'), isNull);
  });

  test('Real original gift movies and pictures are registered in Flutter',
      () async {
    for (final path in [
      'assets/gifts/free/rocket.svga',
      'assets/gifts/free/sports_car.svga',
      'assets/gifts/free/rocket.png',
      'assets/gifts/free/rose.png',
      'assets/gifts/free/heart.png',
      'assets/gifts/free/diamond.png',
      'assets/gifts/free/crown.png',
    ]) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(7000), reason: path);
    }
  });

  testWidgets('Sports Car artwork is a real SVGA animation, not fake text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GiftArtwork(
          name: 'Sports Car',
          assetPath: 'assets/gifts/free/sports_car.svga',
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Sports Car'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
