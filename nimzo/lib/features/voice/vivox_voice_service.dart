import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'voice_service.dart';

/// Owns one Vivox room. A successful join request is not an audio connection.
class VivoxVoiceService implements VoiceService {
  static const MethodChannel _channel = MethodChannel('nimzo/vivox');
  final Future<Map<String, dynamic>> Function(String) _tokenIssuer;
  final Duration connectionTimeout;
  final _speaking = StreamController<Set<String>>.broadcast();
  final _connectedEvents = StreamController<bool>.broadcast();
  @override
  Stream<bool> get connected => _connectedEvents.stream;

  final Set<String> _speakingUsers = <String>{};
  bool _initialized = false, _connected = false, _disposed = false;
  Completer<void>? _connection;
  Future<void> _operations = Future.value();

  VivoxVoiceService({
    Future<Map<String, dynamic>> Function(String)? tokenIssuer,
    this.connectionTimeout = const Duration(seconds: 25),
  }) : _tokenIssuer = tokenIssuer ?? _issueVoiceToken {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  @override
  Stream<Set<String>> get speaking => _speaking.stream;

  Future<dynamic> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return null;
    final args = call.arguments is Map ? call.arguments as Map : const {};
    final detail = '${args['detail'] ?? ''}';
    final status = (args['status'] as num?)?.toInt() ?? 0;
    if (call.method == 'audioConnected' && status == 0 && _connection != null) {
      _connected = true;
      _connectedEvents.add(true);
      if (_connection?.isCompleted == false) _connection!.complete();
    } else if (call.method == 'error' ||
        (status != 0 &&
            (call.method == 'audioState' || call.method == 'loginState'))) {
      _connected = false;
      _connectedEvents.add(false);
      if (_connection?.isCompleted == false) {
        _connection!.completeError(
          StateError('Voice connection failed ($status): $detail'),
        );
      }
    } else if (call.method == 'speaking' || call.method == 'stoppedSpeaking') {
      // Vivox account URI: sip:.issuer.<Supabase UUID>@domain.
      final id = RegExp(
        r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(?=@|$)',
      ).firstMatch(detail)?.group(1);
      if (id != null) {
        call.method == 'speaking'
            ? _speakingUsers.add(id)
            : _speakingUsers.remove(id);
        _speaking.add(Set.unmodifiable(_speakingUsers));
      }
    } else if (call.method == 'left' || call.method == 'audioDisconnected') {
      _connected = false;
      _connectedEvents.add(false);
      _speakingUsers.clear();
      _speaking.add(const <String>{});
    }
    return null;
  }

  static Future<Map<String, dynamic>> _issueVoiceToken(String roomId) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null)
      throw StateError('You must be signed in before joining voice.');
    final response = await client.functions.invoke(
      'voice-token',
      body: {'room': roomId},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.data is! Map)
      throw StateError('Invalid voice-token response.');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> join(String roomId, String token) => _serialize(() async {
    if (_disposed) throw StateError('Voice service is closed.');
    if (_initialized) await _leave();
    // Vivox requires capture access before joining even when initially muted.
    if (await _channel.invokeMethod<bool>('requestMicPermission') != true) {
      throw StateError('Microphone permission is required for room audio.');
    }
    final data = await _tokenIssuer(roomId);
    for (final key in ['loginToken', 'channelToken', 'server', 'channelUri']) {
      if (data[key] is! String || (data[key] as String).isEmpty) {
        throw StateError('Vivox voice-token response is incomplete.');
      }
    }
    if (!_initialized) {
      final ok = await _channel.invokeMethod<bool>('initialize', {
        'server': data['server'],
      });
      if (ok != true) {
        await _channel.invokeMethod<int>('shutdown');
        throw StateError('Vivox SDK initialization failed.');
      }
      _initialized = true;
    }
    _connected = false;
    final pending = Completer<void>();
    _connection = pending;
    // Attach the timeout/error handler before native callbacks can arrive.
    final connected = pending.future.timeout(connectionTimeout);
    // Consume errors immediately while the native join response is pending.
    unawaited(connected.catchError((Object _) {}));
    try {
      final result = await _channel.invokeMethod<int>('join', {
        'loginToken': data['loginToken'],
        'channelToken': data['channelToken'],
        'channelUri': data['channelUri'],
      });
      if (result != 0) throw StateError('Vivox join failed (code $result).');
      await connected;
      await _channel.invokeMethod<int>('setMic', {'enabled': false});
    } catch (_) {
      await _leave();
      rethrow;
    } finally {
      _connection = null;
    }
  });

  Future<void> _leave() async {
    _connected = false;
    if (!_disposed) _connectedEvents.add(false);
    if (_initialized) await _channel.invokeMethod<int>('leave');
    _speakingUsers.clear();
    if (!_disposed) _speaking.add(const <String>{});
  }

  @override
  Future<void> leave() {
    _connected = false;
    if (_connection?.isCompleted == false)
      _connection!.completeError(StateError('Voice join cancelled.'));
    return _serialize(_leave);
  }

  @override
  Future<void> setMicEnabled(bool enabled) => _serialize(() async {
    if (_disposed || !_connected)
      throw StateError('Voice audio is not connected.');
    if (enabled &&
        await _channel.invokeMethod<bool>('requestMicPermission') != true) {
      throw StateError('Microphone permission is required to speak.');
    }
    final result = await _channel.invokeMethod<int>('setMic', {
      'enabled': enabled,
    });
    if (result != 0)
      throw StateError('Vivox microphone request failed (code $result).');
  });

  @override
  Future<void> setSpeakerEnabled(bool enabled) => _serialize(() async {
    if (_disposed || !_connected)
      throw StateError('Voice audio is not connected.');
    final result = await _channel.invokeMethod<int>('setSpeaker', {
      'enabled': enabled,
    });
    if (result != 0)
      throw StateError('Vivox speaker request failed (code $result).');
  });

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await leave();
    } finally {
      await _serialize(() async {
        _disposed = true;
        try {
          if (_initialized) await _channel.invokeMethod<int>('shutdown');
        } finally {
          _initialized = false;
          _channel.setMethodCallHandler(null);
          await _speaking.close();
          await _connectedEvents.close();
        }
      });
    }
  }
}
