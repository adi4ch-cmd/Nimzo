import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile_level_scale.dart';

void main() {
  test('Falla asset ranges retain full original extended levels', () {
    expect(ProfileLevelScale.maxLevels, [270, 270, 140]);
    expect(ProfileLevelScale.levelFor(0, 10000 * 270 * 270), 270);
    expect(ProfileLevelScale.levelFor(1, 100 * 270 * 270), 270);
    expect(ProfileLevelScale.levelFor(2, 20 * 140 * 140), 140);
    expect(ProfileLevelScale.nextRequirement(0, 270),
        ProfileLevelScale.requiredFor(0, 270));
    expect(ProfileLevelScale.fraction(0, 270, 999999999999), 1);
  });

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

  test('partial progress is bounded by current and next verified levels', () {
    const kind = 1;
    expect(ProfileLevelScale.fraction(kind, 2, 100), 0);
    expect(ProfileLevelScale.fraction(kind, 2, 250), closeTo(.5, .001));
    expect(ProfileLevelScale.fraction(kind, 2, 400), 1);
    expect(ProfileLevelScale.levelFor(0, -10), 1);
  });
}
