import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'voice_service.dart';

class VivoxVoiceService implements VoiceService {
  static const MethodChannel _channel = MethodChannel('nimzo/vivox');
  final _speaking = StreamController<Set<String>>.broadcast();
  final Set<String> _speakingUsers = <String>{};
  bool _initialized = false;

  VivoxVoiceService() {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  @override
  Stream<Set<String>> get speaking => _speaking.stream;

  Future<dynamic> _handleNativeEvent(MethodCall call) async {
    final args = (call.arguments is Map)
        ? Map<dynamic, dynamic>.from(call.arguments as Map)
        : <dynamic, dynamic>{};
    final detail = '${args['detail'] ?? ''}';

    if (call.method == 'speaking') {
      if (detail.isNotEmpty) _speakingUsers.add(detail);
      _speaking.add(Set.unmodifiable(_speakingUsers));
    } else if (call.method == 'stoppedSpeaking') {
      if (detail.isNotEmpty) _speakingUsers.remove(detail);
      _speaking.add(Set.unmodifiable(_speakingUsers));
    } else if (call.method == 'left') {
      _speakingUsers.clear();
      _speaking.add(const <String>{});
    }
    return null;
  }

  Future<Map<String, dynamic>> _issueVoiceToken(String roomId) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) throw StateError('You must be signed in before joining voice.');

    final response = await client.functions.invoke(
      'voice-token',
      body: {'room': roomId},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.data is! Map) throw StateError('Invalid voice-token response.');
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<void> join(String roomId, String token) async {
    final data = await _issueVoiceToken(roomId);
    final loginToken = data['loginToken'] as String?;
    final channelToken = data['channelToken'] as String?;
    final server = data['server'] as String?;
    final channelUri = data['channelUri'] as String?;
    if (loginToken == null || channelToken == null || server == null || channelUri == null) {
      throw StateError('Vivox voice-token response is incomplete.');
    }

    if (!_initialized) {
      final ok = await _channel.invokeMethod<bool>('initialize', {'server': server});
      if (ok != true) throw StateError('Vivox SDK initialization failed.');
      _initialized = true;
    }

    final result = await _channel.invokeMethod<int>('join', {
      'loginToken': loginToken,
      'channelToken': channelToken,
      'channelUri': channelUri,
    });
    if (result != 0) throw StateError('Vivox join failed (code $result).');
  }

  @override
  Future<void> leave() async {
    await _channel.invokeMethod<int>('leave');
    _speakingUsers.clear();
    _speaking.add(const <String>{});
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<int>('setMic', {'enabled': enabled});
    if (result != 0) throw StateError('Vivox microphone request failed (code $result).');
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<int>('setSpeaker', {'enabled': enabled});
    if (result != 0) throw StateError('Vivox speaker request failed (code $result).');
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<int>('leave');
      await _channel.invokeMethod<int>('shutdown');
    } finally {
      await _speaking.close();
    }
  }
}
