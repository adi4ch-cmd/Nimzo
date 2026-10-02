/// UI -> VoiceController -> VoiceService -> (Vivox | own server).
abstract class VoiceService {
  Future<void> join(String roomId, String token);
  Future<void> leave();
  Future<void> setMicEnabled(bool enabled);
  Future<void> setSpeakerEnabled(bool enabled);
  /// User ids currently speaking, emitted locally (not via the database).
  Stream<Set<String>> get speaking;
  Future<void> dispose();
}
