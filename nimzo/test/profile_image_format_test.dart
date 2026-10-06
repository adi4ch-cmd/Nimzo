import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile_image_format.dart';

void main() {
  test('gallery PNG keeps its actual media type', () {
    expect(profileImageFormat([137,80,78,71,13,10,26,10]), ('png','image/png'));
    expect(profileImageFormat([255,216,255]), ('jpg','image/jpeg'));
    expect(profileImageFormat('RIFFxxxxWEBP'.codeUnits), ('webp','image/webp'));
  });
  test('unsupported bytes are not relabeled as a JPEG', () {
    expect(() => profileImageFormat('not a photo'.codeUnits), throwsFormatException);
  });
}
