/// Coordinates late database/voice joins with room disposal. No widget Ref survives an await.
class RoomSession {
  final Future<void> Function() joinRoom, leaveRoom, joinVoice, leaveVoice;
  bool joined = false, closed = false;
  DateTime? enteredAt;
  Future<void>? _joining, _closing;
  RoomSession(
      {required this.joinRoom,
      required this.leaveRoom,
      required this.joinVoice,
      required this.leaveVoice});
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
    return _closing ??= _close();
  }

  Future<void> _close() async {
    try {
      await leaveVoice();
    } finally {
      try {
        await _joining;
      } catch (_) {/* A cancelled voice join still needs membership cleanup. */}
      if (joined) {
        await leaveRoom();
        joined = false;
      }
    }
  }
}
