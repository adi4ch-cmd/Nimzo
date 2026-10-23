import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/verified_level_up_tracker.dart';

void main() {
  test('first server read is a baseline, never a fake celebration', () {
    final tracker = VerifiedLevelUpTracker();
    expect(tracker.observe('alice', [1, 5, 2]), isEmpty);
    expect(tracker.observe('alice', [1, 5, 2]), isEmpty);
  });

  test('notifies only genuine server-derived increases', () {
    final tracker = VerifiedLevelUpTracker();
    tracker.observe('alice', [1, 1, 0]);
    final upgrades = tracker.observe('alice', [2, 3, 1]);
    expect(upgrades.map((u) => u.kind).toList(), [0, 1, 2]);
    expect(upgrades.map((u) => u.from).toList(), [1, 1, 0]);
    expect(upgrades.map((u) => u.to).toList(), [2, 3, 1]);
    expect(tracker.observe('alice', [2, 2, 1]), isEmpty);
  });

  test('switching to a new account never announces old account XP', () {
    final tracker = VerifiedLevelUpTracker();
    tracker.observe('alice', [30, 20, 10]);
    expect(tracker.observe('bob', [50, 25, 11]), isEmpty);
    final upgrades = tracker.observe('bob', [51, 25, 11]);
    expect(upgrades.length, 1);
    expect(upgrades.single.kind, 0);
  });

  test('negative values are sanitized and malformed vectors rejected', () {
    final tracker = VerifiedLevelUpTracker();
    expect(tracker.observe('alice', [-1, 0, 0]), isEmpty);
    expect(tracker.observe('alice', [1, 0, 0]).single.to, 1);
    expect(() => tracker.observe('alice', [4, 5]), throwsArgumentError);
  });
}
