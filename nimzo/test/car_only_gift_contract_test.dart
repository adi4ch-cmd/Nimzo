import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/gifts/gift_svga_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const carId = '35e4c570-cb02-4466-ae86-d670b3fb05ab';

  test('only Sports Car artwork and original animated SVGA are bundled', () async {
    expect(freeGiftArtwork('Sports Car'),
        'assets/gifts/free/sports_car.png');
    expect(freeGiftAnimationForId(carId),
        'assets/gifts/free/sports_car.svga');
    expect(freeGiftAnimationsById.keys, contains(carId));
    expect(freeGiftAnimationsById.length, 1);

    for (final path in [
      'assets/gifts/free/sports_car.png',
      'assets/gifts/free/sports_car.svga',
    ]) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(1024), reason: path);
    }

    for (final retired in [
      'Dragon', 'Golden Dragon', 'Phoenix', 'Rose', 'Rocket',
      'Heart', 'Crown', 'Cat', 'Birthday Cake', 'Private Jet',
      'Luxury Yacht', 'Diamond Ring',
    ]) {
      expect(freeGiftArtwork(retired), isNull, reason: retired);
      expect(freeGiftAnimationForName(retired), isNull, reason: retired);
      expect(referenceGiftArtwork(retired), isNull, reason: retired);
      expect(originalNimzoGiftArtwork(retired), isNull, reason: retired);
    }
  });

  test('retired binaries and custom effects are absent from the source tree', () {
    for (final path in [
      'assets/gifts/dragon_1m.mp4',
      'assets/gifts/golden_dragon_5m.mp4',
      'assets/gifts/free/rocket.svga',
      'assets/reference/icons/medal.svg',
      'lib/features/gifts/nimzo_custom_gift_effect.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/gifts/free/'));
    expect(pubspec, isNot(contains('assets/nimzo_custom_gifts/')));
    expect(pubspec, isNot(contains('assets/reference/gift/')));
  });
}
