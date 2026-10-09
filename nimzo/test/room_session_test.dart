import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/room_session.dart';

void main() {
  test('closing during database join removes late membership and never starts voice', () async {
    final pending = Completer<void>();
    var voices = 0, leaves = 0;
    final session = RoomSession(
      joinRoom: () => pending.future,
      leaveRoom: () async {
        leaves++;
      },
      joinVoice: () async {
        voices++;
      },
      leaveVoice: () async {},
    );
    final join = session.join();
    final close = session.close();
    pending.complete();
    await join;
    await close;
    expect(voices, 0);
    expect(leaves, 1);
    expect(session.joined, false);
  });
  test(
    'close is idempotent and closes voice before releasing membership',
    () async {
      final calls = <String>[];
      final session = RoomSession(
        joinRoom: () async {},
        leaveRoom: () async {
          calls.add('room');
        },
        joinVoice: () async {},
        leaveVoice: () async {
          calls.add('voice');
        },
      );
      await session.join();
      await Future.wait([session.close(), session.close()]);
      expect(calls, ['voice', 'room']);
    },
  );
}
