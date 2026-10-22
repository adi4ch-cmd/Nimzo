import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/core/services/catalog_snapshot_cache.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('last-good snapshots are isolated by account and channel', () async {
    await CatalogSnapshotCache.save('alice', 'gifts', [
      {'id': 'gift-a'}
    ]);
    expect(await CatalogSnapshotCache.read('alice', 'gifts'), [
      {'id': 'gift-a'}
    ]);
    expect(await CatalogSnapshotCache.read('bob', 'gifts'), isNull);
    expect(await CatalogSnapshotCache.read('alice', 'store'), isNull);
  });
  test('expired future malformed and oversized snapshots cannot load',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final name =
        'nimzo.catalog.v1.${base64Url.encode(utf8.encode('alice'))}.store';
    for (final saved in [
      DateTime.now().subtract(const Duration(hours: 25)),
      DateTime.now().add(const Duration(hours: 1))
    ]) {
      await prefs.setString(
          name,
          jsonEncode(
              {'saved_at': saved.toUtc().toIso8601String(), 'payload': []}));
      expect(await CatalogSnapshotCache.read('alice', 'store'), isNull);
    }
    await prefs.setString(name, 'bad-json');
    expect(await CatalogSnapshotCache.read('alice', 'store'), isNull);
    await CatalogSnapshotCache.save(
        'alice', 'store', 'x' * (2 * 1024 * 1024 + 1));
    expect(await CatalogSnapshotCache.read('alice', 'store'), isNull);
  });
  test('expired equipment excluded and existing lifetime ownership preserved',
      () {
    final snapshot = NimzoStoreSnapshot.fromRows({
      'catalog': [
        {
          'id': 'lifetime',
          'category': 'Avatar Frame',
          'name': 'Frame',
          'variant': 0,
          'coin_price': 100,
          'duration_days': null
        },
        {
          'id': 'rental',
          'category': 'Rides',
          'name': 'Ride',
          'variant': 1,
          'coin_price': 200,
          'duration_days': 7
        },
      ],
      'ownership': [
        {'item_id': 'lifetime', 'expires_at': null},
        {'item_id': 'rental', 'expires_at': '2026-10-20T00:00:00Z'},
        {'item_id': 'active', 'expires_at': '2026-10-22T00:00:00Z'},
        {'item_id': 'bad', 'expires_at': 'invalid'},
      ],
      'equipped': [
        {'category': 'Avatar Frame', 'item_id': 'lifetime'},
        {'category': 'Rides', 'item_id': 'rental'},
      ],
    }, now: DateTime.utc(2026, 10, 21), offline: true);
    expect(snapshot.owned, {'lifetime', 'active'});
    expect(snapshot.equipped, {'Avatar Frame': 'lifetime'});
    expect(snapshot.items.last.durationDays, 7);
    expect(snapshot.offline, isTrue);
  });
}
