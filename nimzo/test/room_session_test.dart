import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/room_session.dart';

void main() {
  test(
      'closing during database join removes late membership and never starts voice',
      () async {
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
  test('a failed server leave can retry and removes stuck membership', () async {
    var leaves = 0;
    final session = RoomSession(
      joinRoom: () async {},
      leaveRoom: () async {
        leaves++;
        if (leaves == 1) throw StateError('Network failure');
      },
      joinVoice: () async {},
      leaveVoice: () async {},
    );
    await session.join();
    await expectLater(session.close(), throwsStateError);
    expect(session.joined, isTrue);
    await session.close();
    expect(leaves, 2);
    expect(session.joined, isFalse);
  });

  test('native voice exit failure never prevents database removal', () async {
    var roomExits = 0;
    final session = RoomSession(
      joinRoom: () async {},
      joinVoice: () async {},
      leaveVoice: () async => throw StateError('Voice SDK unavailable'),
      leaveRoom: () async { roomExits++; },
    );
    await session.join();
    await session.close();
    expect(roomExits, 1);
    expect(session.joined, isFalse);
  });

}
