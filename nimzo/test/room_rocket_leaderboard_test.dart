import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_leaderboard.dart';

void main() {
  test('verified gift podium parses earned values without inventing medals', () {
    final member = RoomRocketLeader.fromJson({
      'rank': 1,
      'user_id': '11111111-1111-4111-8111-111111111111',
      'nimzo_id': 100005,
      'display_name': 'Member',
      'avatar_path': null,
      'gifted_coins': 5500000,
    });
    expect(member.rank, 1);
    expect(member.giftedCoins, 5500000);
    expect(member.nimzoId, 100005);
    expect(member.displayName, 'Member');
  });

  test('rejects forged or invalid place and negative contribution', () {
    for (final rank in [-1, 0, 4]) {
      expect(
        () => RoomRocketLeader.fromJson({
          'rank': rank, 'user_id': 'u', 'nimzo_id': 123,
          'display_name': 'A', 'gifted_coins': 1,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => RoomRocketLeader.fromJson({
        'rank': 2, 'user_id': 'u', 'nimzo_id': 123,
        'display_name': 'A', 'gifted_coins': -1,
      }),
      throwsFormatException,
    );
  });
}
