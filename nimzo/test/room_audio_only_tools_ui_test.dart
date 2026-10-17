import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';

void main() {
  test('Party Tools expose music and voice features but never video', () {
    expect(roomToolNames, contains('Music'));
    expect(roomToolNames, contains('Broadcast'));
    expect(roomToolNames, contains('Clean'));
    expect(roomToolNames, isNot(contains('Video')));
    expect(roomToolNames.toSet().length, roomToolNames.length);
  });
}
