import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';

void main() {
  test('compatible live gift names retain reference identity', () {
    expect(referenceGiftArtwork(' Rose '), 'assets/reference/gift/1.jpg');
    expect(referenceGiftArtwork('Heart'), 'assets/reference/gift/2.jpg');
    expect(referenceGiftArtwork('Royal Dragon'), 'assets/reference/gift/8.jpg');
  });
  test('unmatched gifts do not invent artwork', () {
    expect(referenceGiftArtwork('Coffee'), isNull);
    expect(referenceGiftArtwork('Unknown'), isNull);
  });
}
