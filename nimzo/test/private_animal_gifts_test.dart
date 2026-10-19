import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/private_animal_gifts.dart';

void main() {
  test('approved animal identities map to 1M catalog gifts', () {
    expect(animalGiftPriceCoins, 1000000);
    expect(privateAnimalGiftIdForName('Ice Fire Phoenix'), phoenixGiftId);
    expect(privateAnimalGiftIdForName(' holy tiger '), holyTigerGiftId);
    expect(privateAnimalGiftIdForName('Tiger'), isNull);
    expect(privateAnimalGiftIdForName('Hall of Fame'), privateHallOfFameGiftId);
    expect(
      privateAnimalGiftIdForName('Dragon Throne'),
      privateDragonThroneGiftId,
    );
  });
  test('premium videos and thumbnails are never bundled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('assets/gifts/ice_fire_phoenix')));
    expect(pubspec, isNot(contains('assets/gifts/holy_tiger')));
    expect(File('assets/gifts/ice_fire_phoenix/video.mp4').existsSync(), false);
    expect(File('assets/gifts/holy_tiger/video.mp4').existsSync(), false);
  });
}
