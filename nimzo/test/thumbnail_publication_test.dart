import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/widgets/published_image.dart';
import 'package:nimzo/features/gifts/gift_artwork.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  Map<String, dynamic> row() => {
        'id': 'new-approved-frame',
        'name': 'Frame',
        'category': 'Avatar Frame',
        'variant': 1,
        'coin_price': 100,
        'media_kind': 'svga',
        'asset_url': 'https://cdn.example/${'a' * 64}.svga',
        'sha256': 'a' * 64,
        'byte_size': 100,
        'mime_type': 'application/x-svga',
        'thumbnail_url': 'https://cdn.example/${'b' * 64}.png',
        'thumbnail_sha256': 'b' * 64,
        'thumbnail_byte_size': 20,
        'thumbnail_mime_type': 'image/png',
      };
  test(
      'Store thumbnail uses its separate descriptor on preview and equipment model',
      () {
    final item = NimzoCosmeticItem.fromJson(row());
    expect(item.publication?.sha256Hex, 'a' * 64);
    expect(item.thumbnailPublication?.sha256Hex, 'b' * 64);
    expect(item.remoteMedia?.thumbnailPublication?.codec, 'png');
    expect(item.remoteMedia?.thumbnailPublication?.byteLength, 20);
  });
  test(
      'new publication omits hashless thumbnail; legacy metadata remains bounded-compatible',
      () {
    final data = row()
      ..remove('thumbnail_sha256')
      ..remove('thumbnail_byte_size')
      ..remove('thumbnail_mime_type');
    final verified = NimzoCosmeticItem.fromJson(data);
    expect(verified.thumbnailUrl, isNull);
    data.remove('sha256');
    data.remove('byte_size');
    data.remove('mime_type');
    expect(NimzoCosmeticItem.fromJson(data).thumbnailUrl, isNotNull);
  });
  test('partial thumbnail metadata cannot silently downgrade', () {
    final data = row()..remove('thumbnail_byte_size');
    expect(() => NimzoCosmeticItem.fromJson(data), throwsFormatException);
  });
  testWidgets(
      'new remote Gift thumbnail without descriptor is unavailable before download',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: GiftArtwork(
            name: 'New Gift',
            assetPath: 'https://cdn.example/thumbnail.png',
            requiresPublication: true)));
    expect(find.byType(PublishedImage), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
