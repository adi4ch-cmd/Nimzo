import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/level_style_catalog.dart';

Map<String, Object> band({String kind = 'wealth', int min = 1, int max = 20}) =>
    {
      'kind': kind,
      'min_level': min,
      'max_level': max,
      'color': 'emerald',
      'glyph': 'diamond',
      'shape': 'pill',
    };
Map<String, Object> catalog(List<Object?> styles) =>
    {'version': 1, 'styles': styles};

void main() {
  test('bands resolve only actual kind and inclusive authoritative level', () {
    final parsed = LevelStyleCatalog.parse(catalog([
      band(),
      band(min: 21, max: 120)..['color'] = 'ruby',
      band(kind: 'charm')..['glyph'] = 'heart',
      band(kind: 'active')..['shape'] = 'rounded',
    ]));
    expect(parsed.styles, hasLength(4));
    expect(parsed.resolve(0, 1)!.color, LevelStyleCatalog.palette['emerald']);
    expect(parsed.resolve(0, 20)!.color, LevelStyleCatalog.palette['emerald']);
    expect(parsed.resolve(0, 21)!.color, LevelStyleCatalog.palette['ruby']);
    expect(parsed.resolve(0, 120)!.maxLevel, 120);
    expect(parsed.resolve(1, 20)!.glyph, Icons.favorite);
    expect(parsed.resolve(2, 20)!.radius, 7);
    for (final level in [-100, 0, 121, 99999]) {
      expect(parsed.resolve(0, level), isNull);
    }
    expect(parsed.resolve(-1, 1), isNull);
    expect(parsed.resolve(3, 1), isNull);
    expect(parsed.resolve(1, 21), isNull);
    expect(() => parsed.styles.clear(), throwsUnsupportedError);
  });

  test('all whitelisted colors glyphs and shapes are supported', () {
    for (final color in LevelStyleCatalog.palette.keys) {
      for (final glyph in LevelStyleCatalog.glyphs.keys) {
        for (final shape in LevelStyleCatalog.shapes) {
          final row = band()
            ..addAll({'color': color, 'glyph': glyph, 'shape': shape});
          expect(
              LevelStyleCatalog.parse(catalog([row])).resolve(0, 1), isNotNull);
        }
      }
    }
  });

  test('malformed unknown or authority-bearing settings fail closed', () {
    final invalid = <Object?>[
      null,
      false,
      [],
      'styles',
      {},
      {'version': 2, 'styles': []},
      {'version': 1.0, 'styles': []},
      {'version': 1, 'styles': {}},
      {'version': 1, 'styles': [], 'level': 120},
      catalog([null]),
      catalog([band()..remove('shape')]),
      catalog([band()..['kind'] = 'vip']),
      catalog([band()..['min_level'] = '1']),
      catalog([band()..['min_level'] = 1.0]),
      catalog([band(min: 0)]),
      catalog([band(max: 121)]),
      catalog([band(min: 21, max: 20)]),
      catalog([band()..['color'] = '#ffffff']),
      catalog([band()..['color'] = 'transparent']),
      catalog([band()..['glyph'] = 'https://example.com/art.svg']),
      catalog([band()..['shape'] = 'full_screen']),
      catalog([band()..['level'] = 120]),
      catalog([band()..['xp'] = 999999]),
      catalog([band()..['grant_coins'] = true]),
      catalog([band()..['label'] = 'VIP']),
      catalog([band()..['image_url'] = 'https://example.com/art.png']),
      catalog([band(), band(min: 20, max: 30)]),
      catalog(List.generate(37, (_) => band())),
    ];
    for (final payload in invalid) {
      expect(LevelStyleCatalog.parse(payload).styles, isEmpty,
          reason: '$payload');
    }
  });
}
