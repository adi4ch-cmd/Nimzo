import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/gifts/gift_svga_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all six complete gift icons are packaged (no blank cards)', () async {
    for (final name in [
      'Rose', 'Heart', 'Crown', 'Diamond', 'Rocket', 'Sports Car'
    ]) {
      final path = freeGiftArtwork(name);
      expect(path, isNotNull, reason: '$name missing an approved image');
      final data = await rootBundle.load(path!);
      expect(data.lengthInBytes, greaterThan(1000), reason: path);
    }
  });

  test('both matching gift animations are actually packaged', () async {
    const known = {
      '99faac6c-933c-4c08-8026-08c39227751e': 'Rocket',
      '35e4c570-cb02-4466-ae86-d670b3fb05ab': 'Sports Car',
    };
    for (final gift in known.entries) {
      final source = freeGiftAnimationForId(gift.key);
      expect(source, isNotNull, reason: gift.value);
      final bytes = await rootBundle.load(source!);
      expect(bytes.lengthInBytes, greaterThan(2000000));
    }
    expect(freeGiftAnimationForName('Phoenix'), isNull);
    expect(freeGiftAnimationForName('Golden Dragon'), isNull);
  });
}
