import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/nimzo_content_sync.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
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
    expect(changedContentChannels([], [
      {'channel': 1, 'revision': 2},
      {'channel': 'gifts', 'revision': null},
    ]), isEmpty);
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
    expect(NimzoCosmeticItem.fromJson(item('http://bad/a.png')).thumbnailUrl, isNull);
    expect(NimzoCosmeticItem.fromJson(item('file:///tmp/a.png')).thumbnailUrl, isNull);
    expect(NimzoCosmeticItem.fromJson(item('https://cdn.example/a.png')).thumbnailUrl,
        'https://cdn.example/a.png');
  });
}
