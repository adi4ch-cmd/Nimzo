/// Coordinates late database/voice joins with room disposal. No widget Ref survives an await.
class RoomSession {
  final Future<void> Function() joinRoom, leaveRoom, joinVoice, leaveVoice;
  bool joined = false, closed = false;
  DateTime? enteredAt;
  Future<void>? _joining, _closing;
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
      await joinRoom();
      joined = true;
      enteredAt = DateTime.now();
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
    // Native voice may fail while the server is reachable. Always remove
    // membership independently; a bad microphone disconnect must not keep
    // the user's identity in room_members.
    try {
      await leaveVoice();
    } catch (_) {
      // Room membership cleanup remains authoritative.
    }
    try {
      await _joining;
    } catch (_) {
      // A failed/cancelled join still needs any late DB membership cleaned.
    }
    if (joined) {
      await leaveRoom();
      joined = false;
    }
  }
}
