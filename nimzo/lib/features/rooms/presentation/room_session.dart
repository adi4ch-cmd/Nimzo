/// Coordinates late database/voice joins with room disposal. No widget Ref survives an await.
class RoomSession {
  final Future<void> Function() joinRoom, leaveRoom, joinVoice, leaveVoice;
  bool joined = false, closed = false;
  DateTime? enteredAt;
  Future<void>? _joining, _databaseJoining, _closing;
  RoomSession({
    required this.joinRoom,
    required this.leaveRoom,
    required this.joinVoice,
    required this.leaveVoice,
  });
  Future<void> join() {
    if (closed) throw StateError('Room session is closed');
    return _joining ??= _join().whenComplete(() => _joining = null);
  }

  Future<void> _join() async {
    if (!joined) {
      // Track DB entry independently so exit never waits on a hung Vivox
      // login before removing authenticated room presence.
      await (_databaseJoining ??= joinRoom().then((_) {
        joined = true;
        enteredAt = DateTime.now();
      }));
      _databaseJoining = null;
    }
    if (closed) return;
    await joinVoice();
  }

  Future<void> close() {
    closed = true;
    return _closing ??= _attemptClose();
  }

  Future<void> _attemptClose() async {
    try {
      await _close();
    } finally {
      // A failed network leave can be retried by the visible room page.
      _closing = null;
    }
  }

  Future<void> _close() async {
    // Prioritize Supabase leave over native SDK teardown. A stalled SDK
    // login must not keep a user visible in room_members or on a mic seat.
    try {
      await _databaseJoining;
    } catch (_) {
      // A rejected DB join created no membership to leave.
    }
    Object? leaveError;
    StackTrace? leaveStack;
    if (joined) {
      try {
        await leaveRoom();
        joined = false;
      } catch (e, st) {
        // Let the room UI offer Retry rather than reporting a false exit.
        leaveError = e;
        leaveStack = st;
      }
    }
    // Native cleanup is best-effort after authoritative database cleanup,
    // never allowed to suppress a failed Supabase leave.
    try {
      await leaveVoice().timeout(const Duration(seconds: 6));
    } catch (_) {
      // A disconnected Vivox client may fail to release native handles.
    }
    if (leaveError != null) Error.throwWithStackTrace(leaveError, leaveStack!);
  }

}
