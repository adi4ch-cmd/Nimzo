import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all six rocket stages bundle BOTH transparent VAP clips', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final names = manifest.listAssets();
    for (var stage = 1; stage <= 6; stage++) {
      for (final part in ['fly','reward']) {
        final path = 'assets/room_rocket/vap_rocket_${part}_${stage}.mp4';
        expect(names, contains(path), reason: path);
        final bytes = await rootBundle.load(path);
        expect(bytes.lengthInBytes, greaterThan(1024), reason: path);
      }
    }
  });

  test('gift grid has no hard-coded separate Coming Soon preview', () {
    final source = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    expect(source, isNot(contains('NewGiftPreviewCollection(')));
    expect(source, isNot(contains('New Gifts - 500K')));
    expect(source, contains('giftCatalogProvider'));
    expect(source, contains('GiftArtwork('));
  });

  test('premium catalog artwork uses authenticated thumbnail service', () {
    final artwork = File('lib/features/gifts/gift_artwork.dart').readAsStringSync();
    final repository = File('lib/features/gifts/gift_repository.dart')
        .readAsStringSync();
    expect(artwork, contains('privatePremiumThumbnailProvider'));
    expect(repository, contains("'gift-media'"));
    expect(repository, contains("kind: 'thumbnail'"));
    expect(repository, contains("kind: 'animation'"));
    expect(repository, contains("approvedAnimationUrl("));
  });

  test('room sends use real VAP alpha animation for private gifts', () {
    final broadcast = File('lib/features/gifts/verified_gift_broadcast.dart')
        .readAsStringSync();
    expect(broadcast, contains('HallOfFameVapOverlay('));
    expect(broadcast, contains('privatePremiumGiftIds.contains('));
    final vap = File('lib/features/gifts/hall_of_fame_vap_overlay.dart')
        .readAsStringSync();
    expect(vap, contains('VapPlayer('));
  });
}
