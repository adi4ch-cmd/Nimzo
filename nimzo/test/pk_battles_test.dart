import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/pk_battles_screen.dart';

void main() {
  test('PK score is from committed room gift totals only', () {
    final match = LivePkMatch.fromJson({
      'match_id': 'm1',
      'room_a': 'a',
      'room_b': 'b',
      'name_a': 'Alpha',
      'name_b': 'Beta',
      'number_a': 100005,
      'number_b': 100006,
      'score_a': 4500,
      'score_b': 1500,
      'ends_at': '2026-10-17T20:00:00Z',
    });
    expect(match.scoreA, 4500);
    expect(match.scoreB, 1500);
    expect(match.progress, closeTo(0.75, 0.00001));
    expect(match.roomNoA, 100005);
  });

  test('PK starts at even progress when no real gift was sent', () {
    final match = LivePkMatch.fromJson({
      'match_id': 'm0', 'room_a': 'a', 'room_b': 'b',
      'name_a': 'A', 'name_b': 'B',
      'number_a': 1, 'number_b': 2,
      'score_a': 0, 'score_b': 0,
      'ends_at': '2026-10-17T20:00:00Z',
    });
    expect(match.progress, 0.5);
  });
}
