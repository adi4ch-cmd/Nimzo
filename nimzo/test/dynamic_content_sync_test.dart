import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/nimzo_content_sync.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  test('high water marks survive out of order snapshots', () {
    final tracker = ContentRevisionTracker();
    expect(
        tracker.accept([
          {'channel': 'gifts', 'revision': 10}
        ]),
        {'gifts'});
    expect(
        tracker.accept([
          {'channel': 'gifts', 'revision': 2}
        ]),
        isEmpty);
    expect(
        tracker.accept([
          {'channel': 'gifts', 'revision': 9}
        ]),
        isEmpty);
    expect(
        tracker.accept([
          {'channel': 'gifts', 'revision': 11}
        ]),
        {'gifts'});
    expect(
        ContentRevisionTracker().accept([
          {'channel': 'gifts', 'revision': 1}
        ]),
        {'gifts'});
  });

  test('fractional negative and zero revisions are not valid publications', () {
    expect(
        changedContentChannels(null, [
          {'channel': 'gifts', 'revision': 1.5},
          {'channel': 'store', 'revision': -1},
          {'channel': 'settings', 'revision': 0},
        ]),
        isEmpty);
  });

  test('initial revision snapshot refreshes available channels', () {
    expect(
      changedContentChannels(null, [
        {'channel': 'gifts', 'revision': 1},
        {'channel': 'store', 'revision': 3},
      ]),
      {'gifts', 'store'},
    );
  });

  test('only increases refresh content, duplicates never refresh', () {
    final before = [
      {'channel': 'gifts', 'revision': 5},
      {'channel': 'store', 'revision': 3},
    ];
    final after = [
      {'channel': 'gifts', 'revision': 5},
      {'channel': 'store', 'revision': 4},
    ];
    expect(changedContentChannels(before, after), {'store'});
    expect(changedContentChannels(after, after), isEmpty);
    expect(changedContentChannels(after, before), isEmpty);
  });

  test('missing/invalid revision records are ignored', () {
    expect(
        changedContentChannels([], [
          {'channel': 1, 'revision': 2},
          {'channel': 'gifts', 'revision': null},
        ]),
        isEmpty);
  });

  test('Store only accepts HTTPS remote thumbnails', () {
    Map<String, dynamic> item(String? url) => {
          'id': 'nimzo-original-frame-test',
          'category': 'Avatar Frame',
          'name': 'Example',
          'variant': 0,
          'coin_price': 0,
          'thumbnail_url': url,
        };
    expect(NimzoCosmeticItem.fromJson(item('http://bad/a.png')).thumbnailUrl,
        isNull);
    expect(NimzoCosmeticItem.fromJson(item('file:///tmp/a.png')).thumbnailUrl,
        isNull);
    expect(
        NimzoCosmeticItem.fromJson(item('https://cdn.example/a.png'))
            .thumbnailUrl,
        'https://cdn.example/a.png');
  });

  test('new approved remote Store item has playable equipment metadata', () {
    final item = NimzoCosmeticItem.fromJson({
      'id': 'new-owner-approved-frame',
      'category': 'Avatar Frame',
      'name': 'Dynamic Frame',
      'variant': 2,
      'coin_price': 0,
      'thumbnail_url': 'https://cdn.example/thumb.png',
      'asset_url': 'https://cdn.example/frame.svga',
      'media_kind': 'svga',
    });
    expect(item.remoteMedia, isNotNull);
    expect(item.remoteMedia?.asset, 'https://cdn.example/frame.svga');
    expect(item.remoteMedia?.category, 'Avatar Frame');
    final unsafe = NimzoCosmeticItem.fromJson({
      'id': 'unsafe',
      'category': 'Avatar Frame',
      'name': 'Unsafe',
      'variant': 1,
      'coin_price': 0,
      'asset_url': 'file:///tmp/secret',
      'media_kind': 'svga',
    });
    expect(unsafe.remoteMedia, isNull);
  });
}
