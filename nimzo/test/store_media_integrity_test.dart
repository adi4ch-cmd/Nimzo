import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  NimzoCosmeticItem item(String id, {
    String? thumbnail,
    String? asset,
    String? format,
  }) => NimzoCosmeticItem.fromJson({
        'id': id,
        'category': 'Avatar Frame',
        'name': 'Real asset review',
        'coin_price': 0,
        'variant': 1,
        'thumbnail_url': thumbnail,
        'asset_url': asset,
        'media_kind': format,
      });

  test('Original bundled animation is a real Store product', () {
    expect(hasVerifiedStoreMedia(
        item('nimzo-media-frame-family')), isTrue);
    expect(hasVerifiedStoreMedia(
        item('nimzo-media-portrait-3')), isTrue);
  });

  test('Owned but unrenderable legacy item cannot pretend to equip', () {
    final orphan = item('nimzo-original-rides-golden-stars');
    expect(hasVerifiedStoreMedia(orphan), isFalse);
    const owned = {'nimzo-original-rides-golden-stars'};
    expect(owned.contains(orphan.id), isTrue,
        reason: 'Existing Backpack ownership must be preserved');
  });

  test('Remote image alone is not proof of complete equipment', () {
    expect(hasVerifiedStoreMedia(item('new-item',
      thumbnail: 'https://cdn.example.com/poster.png')), isFalse);
    expect(hasVerifiedStoreMedia(item('new-item',
      asset: 'http://bad.example.com/frame.svga',
      format: 'svga')), isFalse);
  });

  test('Approved remote full-media entry becomes equipable', () {
    expect(hasVerifiedStoreMedia(item('new-item',
      asset: 'https://cdn.example.com/frame.svga',
      thumbnail: 'https://cdn.example.com/frame.png',
      format: 'svga')), isTrue);
  });
}
