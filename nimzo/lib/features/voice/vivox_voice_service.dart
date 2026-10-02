import 'dart:async';
import 'voice_service.dart';

/// TODO: bind Vivox native SDKs (Android/iOS) through a MethodChannel.
/// `token` must come from a Supabase Edge Function that signs it with
/// Vivox credentials. Those credentials never live in the app.
class VivoxVoiceService implements VoiceService {
  final _speaking = StreamController<Set<String>>.broadcast();
  @override
  Stream<Set<String>> get speaking => _speaking.stream;
  @override
  Future<void> join(String roomId, String token) async =>
      throw UnimplementedError('Vivox channel not wired');
  @override
  Future<void> leave() async {}
  @override
  Future<void> setMicEnabled(bool enabled) async {}
  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}
  @override
  Future<void> dispose() => _speaking.close();
}
