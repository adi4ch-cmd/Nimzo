import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/honors/honor_milestone.dart';

void main() {
  test('server eligibility and timestamp are authoritative', () {
    final honor = HonorMilestone.fromJson({
      'code': 'first_gift',
      'title': 'First gift',
      'category': 'Giving',
      'description': 'Send a gift to another member.',
      'progress': 1,
      'target': 1,
      'earned': false,
      'earned_at': null,
    });
    expect(honor.earned, isFalse);
    expect(honor.earnedAt, isNull);
    expect(honor.fraction, 1);
  });
  test('progress is bounded for display without changing actual progress', () {
    final honor = HonorMilestone.fromJson({
      'code': 'rounds_10',
      'title': 'Ten rounds',
      'category': 'Games',
      'description': 'Finish ten rounds.',
      'progress': 25,
      'target': 10,
      'earned': true,
      'earned_at': '2026-10-21T03:00:00Z',
    });
    expect(honor.progress, 25);
    expect(honor.fraction, 1);
    expect(honor.earnedAt, DateTime.utc(2026, 10, 21, 3));
  });
}
