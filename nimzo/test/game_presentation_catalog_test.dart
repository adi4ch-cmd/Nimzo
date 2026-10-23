import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/game_presentation_catalog.dart';
import 'package:nimzo/features/events/dynamic_event_banners.dart';

Map<String, Object> image() => {
      'url': 'https://cdn.example/${'a' * 64}.png',
      'sha256': 'a' * 64,
      'byte_size': 512,
      'mime_type': 'image/png',
      'rights_reference': 'owner-scope',
      'verified_at': '2026-10-21T00:00:00Z',
      'device_verified_at': '2026-10-21T00:00:00Z'
    };
Map<String, Object> game() => {
      'slug': 'fruit_party',
      'title': 'Fruit Party',
      'category': 'Party',
      'image': image()
    };
void main() {
  test('known engines receive complete approved art only', () {
    expect(
        GamePresentationCatalog.parse({
          'version': 1,
          'games': [game()]
        }).games.keys,
        ['fruit_party']);
    for (final row in [
      {...game(), 'slug': 'remote_executable'},
      {...game(), 'engine': 'url'},
      {...game(), 'category': 'Admin'},
      {...game(), 'title': 'bad\u202etext'},
      {
        ...game(),
        'image': {...image(), 'url': 'https://cdn.example/latest.png'}
      },
      {
        ...game(),
        'image': {...image()}..remove('device_verified_at')
      },
    ]) {
      expect(
          GamePresentationCatalog.parse({
            'version': 1,
            'games': [row]
          }).games,
          isEmpty);
    }
    expect(
        GamePresentationCatalog.parse({
          'version': 1,
          'games': [game(), game()]
        }).games,
        isEmpty);
  });
  test('new campaign metadata must be complete; legacy dates still respected',
      () {
    final now = DateTime.utc(2026, 10, 22);
    final row = {
      'id': 'event',
      'title': 'Campaign',
      'active': true,
      'image_path': image()['url'],
      'image_sha256': image()['sha256'],
      'image_byte_size': 512,
      'image_mime_type': 'image/png',
      'image_rights_reference': 'owner-scope',
      'image_verified_at': '2026-10-21T00:00:00Z',
      'image_device_verified_at': '2026-10-21T00:00:00Z'
    };
    NimzoEventBanner? parse(Map<String, Object?> r) =>
        NimzoEventBanner.fromRow(r,
            resolveStorage: (p) => 'https://storage.example/$p', now: now);
    expect(parse(row)?.publication, isNotNull);
    expect(parse({...row, 'image_byte_size': null}), isNull);
    expect(parse({...row, 'end_at': '2026-10-21T00:00:00Z'}), isNull);
    expect(
        parse({
          'id': 'legacy',
          'title': 'Old',
          'active': true,
          'image_path': 'old.png'
        }),
        isNotNull);
  });
}
