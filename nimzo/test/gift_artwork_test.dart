import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';

void main() {
  test('compatible live gift names retain reference identity', () {
    expect(referenceGiftArtwork(' Rose '), 'assets/reference/gift/1.jpg');
    expect(referenceGiftArtwork('Heart'), 'assets/reference/gift/2.jpg');
    expect(referenceGiftArtwork('Royal Dragon'), 'assets/reference/gift/8.jpg');
  });
  test(
    'original Dragon catalog posters use their own original video frames',
    () {
      expect(
        originalDragonPoster('Dragon'),
        'assets/gifts/dragon_1m_poster.webp',
      );
      expect(
        originalDragonPoster(' Golden Dragon '),
        'assets/gifts/golden_dragon_5m_poster.webp',
      );
      expect(originalDragonPoster('Rose'), isNull);
    },
  );
  test('complete free gifts have actual locally pinned icon paths', () {
    for (final name in [
      'Rose', 'Heart', 'Diamond', 'Crown', 'Rocket', 'Sports Car'
    ]) {
      expect(freeGiftArtwork(name), startsWith('assets/gifts/free/'));
      expect(freeGiftArtwork(name), endsWith('.png'));
    }
    expect(freeGiftArtwork('Golden Palace'), isNull);
    expect(freeGiftArtwork('Phoenix'), isNull);
  });
  test('all fourteen original NIMZO gift names have unique SVG artwork', () {
    const names = [
      'Kiss','Coffee','Cat','Birthday Cake','Teddy Bear','Gift Box',
      'Panda','Diamond Ring','Golden Palace','Private Jet',
      'Luxury Yacht','Dragon','Golden Dragon','Phoenix'
    ];
    final paths = names.map(originalNimzoGiftArtwork).toList();
    expect(paths.every((p) => p != null && p.endsWith('.svg')), isTrue);
    expect(paths.toSet().length, names.length);
  });
  test('unmatched gifts do not invent artwork', () {
    expect(referenceGiftArtwork('Coffee'), isNull);
    expect(referenceGiftArtwork('Unknown'), isNull);
  });
}
