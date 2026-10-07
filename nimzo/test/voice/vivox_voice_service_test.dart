import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/voice/vivox_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nimzo/vivox');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 0);
  });
  test('microphone cannot transmit before audio connection', () async {
    final voice = VivoxVoiceService();
    await expectLater(voice.setMicEnabled(true), throwsStateError);
    await voice.dispose();
  });
  test('speaking SIP identity maps to profile UUID', () async {
    final voice = VivoxVoiceService();
    const id = 'c3d02bfb-a0f0-4ef9-b19f-10409dcb59af';
    final event = voice.speaking.first;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'nimzo/vivox',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('speaking', {
          'detail': 'sip:.issuer.$id.@voice.example',
          'status': 0,
        }),
      ),
      (_) {},
    );
    expect(await event, {id});
    await voice.dispose();
  });
  Future<void> emit(String event, {int status = 0}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'nimzo/vivox',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(event, {'status': status, 'detail': 'test'}),
      ),
      (_) {},
    );
  }

  const credentials = {
    'loginToken': 'login',
    'channelToken': 'join',
    'server': 'https://voice.example',
    'channelUri': 'sip:room@voice.example',
    'canTransmit': true,
  };
  test(
    'join waits for media confirmation rather than native request acceptance',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return call.method == 'initialize' ||
                call.method == 'requestMicPermission'
            ? true
            : 0;
      });
      var completed = false;
      final joined = voice.join('room', '').then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(methods, ['requestMicPermission', 'initialize', 'join']);
      expect(completed, false);
      await emit('audioConnected');
      await joined;
      expect(methods.last, 'setMic');
      await voice.dispose();
    },
  );
  test('failed initial mute rejects join and leaves native channel', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'join') await emit('audioConnected');
      if (call.method == 'setMic') return 17;
      return call.method == 'initialize' ||
              call.method == 'requestMicPermission'
          ? true
          : 0;
    });
    await expectLater(voice.join('room', ''), throwsStateError);
    expect(methods.last, 'leave');
    await expectLater(voice.setMicEnabled(true), throwsStateError);
    await voice.dispose();
  });
  test('native error clears stale speaking indicators', () async {
    final voice = VivoxVoiceService();
    const id = 'c3d02bfb-a0f0-4ef9-b19f-10409dcb59af';
    final states = <Set<String>>[];
    final subscription = voice.speaking.listen(states.add);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
            'nimzo/vivox',
            const StandardMethodCodec().encodeMethodCall(const MethodCall(
                'speaking',
                {'detail': 'sip:.issuer.$id.@voice.example', 'status': 0})),
            (_) {});
    await emit('error', status: 500);
    await Future<void>.delayed(Duration.zero);
    expect(states, [
      {id},
      <String>{}
    ]);
    await subscription.cancel();
    await voice.dispose();
  });
  test('native media failure fails join and cleans up', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'join') await emit('error', status: 403);
      return call.method == 'initialize' ||
              call.method == 'requestMicPermission'
          ? true
          : 0;
    });
    await expectLater(voice.join('room', ''), throwsStateError);
    expect(methods.last, 'leave');
    await voice.dispose();
  });
  test(
    'leaving cancels an in-flight join and prevents microphone transmission',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'initialize' || call.method == 'requestMicPermission'
                ? true
                : 0,
      );
      final joined = voice.join('room', '');
      final cancelled = expectLater(joined, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await voice.leave();
      await cancelled;
      await expectLater(voice.setMicEnabled(true), throwsStateError);
      await voice.dispose();
    },
  );
  test('denied microphone permission leaves native microphone muted', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    final enabledRequests = <bool>[];
    var permissionRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'join') await emit('audioConnected');
      if (call.method == 'setMic')
        enabledRequests.add((call.arguments as Map)['enabled'] as bool);
      if (call.method == 'requestMicPermission')
        return ++permissionRequests == 1;
      return call.method == 'initialize' ||
              call.method == 'requestMicPermission'
          ? true
          : 0;
    });
    await voice.join('room', '');
    await expectLater(voice.setMicEnabled(true), throwsStateError);
    expect(enabledRequests, [false]);
    await voice.dispose();
  });
  test(
    'listener upgrades to a fresh server-authorized join before transmitting',
    () async {
      var issued = 0;
      final voice = VivoxVoiceService(
        tokenIssuer: (_) async => {...credentials, 'canTransmit': ++issued > 1},
      );
      var joins = 0;
      final states = <bool>[];
      final subscription = voice.connected.listen(states.add);
      final mic = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'join') {
          joins++;
          await emit('audioConnected');
        }
        if (call.method == 'setMic')
          mic.add((call.arguments as Map)['enabled'] as bool);
        return call.method == 'initialize' ||
                call.method == 'requestMicPermission'
            ? true
            : 0;
      });
      await voice.join('room', '');
      await voice.setMicEnabled(true);
      expect(joins, 2);
      expect(mic, [false, false, true]);
      await Future<void>.delayed(Duration.zero);
      expect(states, [true, false, true]);
      // Reconnection restores microphone controls; a moderator can still mute.
      await voice.setMicEnabled(false);
      expect(mic.last, false);
      await subscription.cancel();
      await voice.dispose();
    },
  );
  test(
    'server-denied transmission disconnects without enabling the microphone',
    () async {
      var issued = 0;
      final voice = VivoxVoiceService(
        tokenIssuer: (_) async => {
          ...credentials,
          'canTransmit': ++issued == 1,
        },
      );
      final mic = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'join') await emit('audioConnected');
        if (call.method == 'setMic')
          mic.add((call.arguments as Map)['enabled'] as bool);
        return call.method == 'initialize' ||
                call.method == 'requestMicPermission'
            ? true
            : 0;
      });
      await voice.join('room', '');
      await expectLater(voice.setMicEnabled(true), throwsStateError);
      expect(mic, [false]);
      await voice.dispose();
    },
  );
}
