import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';

void main() {
  test('gift availability uses inclusive start and exclusive expiry', () {
    final now = DateTime.utc(2026, 10, 22, 12);
    expect(giftIsAvailable({}, now: now), isTrue);
    expect(giftIsAvailable({'available_from': now.toIso8601String()}, now: now),
        isTrue);
    expect(
        giftIsAvailable({'available_until': now.toIso8601String()}, now: now),
        isFalse);
    expect(
        giftIsAvailable({
          'available_from':
              now.add(const Duration(seconds: 1)).toIso8601String()
        }, now: now),
        isFalse);
    expect(giftIsAvailable({'available_until': 'invalid'}, now: now), isFalse);
  });
  test('published gift sound is explicitly controlled by catalog', () {
    final row = {
      'video_url': 'https://cdn.example/${'a' * 64}.mp4',
      'media_kind': 'vap',
      'sha256': 'a' * 64,
      'byte_size': 100,
      'mime_type': 'video/mp4'
    };
    expect(GiftPlaybackMedia.fromRow(row)?.soundEnabled, isFalse);
    expect(
        GiftPlaybackMedia.fromRow({...row, 'sound_enabled': true})
            ?.soundEnabled,
        isTrue);
  });
}
