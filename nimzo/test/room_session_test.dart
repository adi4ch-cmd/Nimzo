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
    'close is idempotent and clears server membership before voice teardown',
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
      expect(calls, ['room', 'voice']);
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

  test('server membership leaves before hung voice login completes', () async {
    final voiceLogin = Completer<void>();
    final calls = <String>[];
    final session = RoomSession(
      joinRoom: () async { calls.add('join-db'); },
      joinVoice: () => voiceLogin.future,
      leaveRoom: () async { calls.add('leave-db'); },
      leaveVoice: () async { calls.add('leave-voice'); },
    );
    final opening = session.join();
    await Future<void>.delayed(Duration.zero);
    expect(session.joined, isTrue);
    await session.close();
    expect(calls, ['join-db', 'leave-db', 'leave-voice']);
    expect(session.joined, false);
    voiceLogin.completeError(StateError('login cancelled'));
    await expectLater(opening, throwsStateError);
  });

  test('failed early database join does not issue phantom exit', () async {
    var leaves = 0;
    final session = RoomSession(
      joinRoom: () async => throw StateError('blocked'),
      joinVoice: () async {},
      leaveRoom: () async { leaves++; },
      leaveVoice: () async {},
    );
    await expectLater(session.join(), throwsStateError);
    await session.close();
    expect(leaves, 0);
  });

}
