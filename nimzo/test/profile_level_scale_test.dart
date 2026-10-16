import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile_level_scale.dart';

void main() {
  test('tier starts match authoritative SQL square-step thresholds', () {
    for (var kind = 0; kind < 3; kind++) {
      final unit = ProfileLevelScale.thresholds[kind];
      expect(ProfileLevelScale.levelFor(kind, 0), 1);
      expect(ProfileLevelScale.levelFor(kind, unit - 1), 1);
      expect(ProfileLevelScale.levelFor(kind, unit), 2);
      expect(ProfileLevelScale.levelFor(kind, unit * 4 - 1), 2);
      expect(ProfileLevelScale.levelFor(kind, unit * 4), 3);
      expect(ProfileLevelScale.nextRequirement(kind, 2), unit * 4);
      expect(ProfileLevelScale.requiredFor(kind, 120),
        119 * 119 * unit);
      expect(ProfileLevelScale.fraction(kind, 1, 0), 0);
      expect(ProfileLevelScale.fraction(kind, 120, unit * 20000), 1);
    }
    expect(ProfileLevelScale.levelFor(0, 39235000), 63);
  });

  test('three level palettes all start differently and evolve with tier', () {
    final first = List.generate(3,
        (k) => ProfileLevelScale.color(k, 1));
    expect(first.toSet().length, 3);
    for (var kind = 0; kind < 3; kind++) {
      expect(ProfileLevelScale.color(kind, 1),
          isNot(ProfileLevelScale.color(kind, 21)));
      expect(ProfileLevelScale.color(kind, 21),
          isNot(ProfileLevelScale.color(kind, 40)));
      expect(ProfileLevelScale.color(kind, 60),
          isNot(ProfileLevelScale.color(kind, 100)));
    }
  });

  test('all tier names match each independently rotated badge color', () {
    const starts = [1, 21, 40, 60, 80, 100];
    const names = [
      ['Brown', 'Green', 'Blue', 'Pink', 'Red', 'Gold'],
      ['Blue', 'Pink', 'Red', 'Gold', 'Brown', 'Green'],
      ['Red', 'Gold', 'Brown', 'Green', 'Blue', 'Pink'],
    ];
    for (var kind = 0; kind < 3; kind++) {
      for (var i = 0; i < starts.length; i++) {
        final level = starts[i];
        expect(ProfileLevelScale.tierName(kind, level), names[kind][i]);
        final canonicalIndex = ProfileLevelScale.tierNames.indexOf(names[kind][i]);
        expect(ProfileLevelScale.color(kind, level),
            ProfileLevelScale.color(0, starts[canonicalIndex]));
      }
    }
    expect(ProfileLevelScale.tierName(1, 0), 'Unavailable');
    expect(ProfileLevelScale.tierName(1, 121), 'Unavailable');
    expect(ProfileLevelScale.tierName(5, 1), 'Unavailable');
  });

  test('partial progress is bounded by current and next verified levels', () {
    const kind = 1;
    expect(ProfileLevelScale.fraction(kind, 2, 100), 0);
    expect(ProfileLevelScale.fraction(kind, 2, 250), closeTo(.5, .001));
    expect(ProfileLevelScale.fraction(kind, 2, 400), 1);
    expect(ProfileLevelScale.levelFor(0, -10), 1);
  });
}
