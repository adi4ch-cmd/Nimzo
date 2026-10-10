import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Future<void> emit(
    String event, {
    int status = 0,
    String detail = 'test',
  }) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'nimzo/vivox',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(event, {'status': status, 'detail': detail}),
      ),
      (_) {},
    );
  }

  const credentials = {
    'loginToken': 'login',
    'channelToken': 'join',
    'server': 'https://voice.example',
    'channelUri': 'sip:room@voice.example',
    'accountUri': 'sip:.issuer.user.@voice.example',
    'canTransmit': true,
  };
  test(
    'failed shutdown clears speaking state and allows a fresh SDK retry',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      var initializations = 0;
      var shutdowns = 0;
      final states = <Set<String>>[];
      final subscription = voice.speaking.listen(states.add);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') initializations++;
        if (call.method == 'join') await emit('audioConnected');
        if (call.method == 'shutdown' && ++shutdowns == 1) {
          throw PlatformException(code: 'VIVOX_NATIVE');
        }
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await voice.join('room', '');
      await emit(
        'speaking',
        detail:
            'sip:.issuer.c3d02bfb-a0f0-4ef9-b19f-10409dcb59af.@voice.example',
      );
      await expectLater(voice.leave(), throwsA(isA<VoiceConnectionFailure>()));
      await Future<void>.delayed(Duration.zero);
      expect(
        states.last,
        isEmpty,
        reason: 'Native teardown failure must clear stale seat activity',
      );
      await voice.join('room', '');
      expect(initializations, 2);
      await subscription.cancel();
      await voice.dispose();
    },
  );
  test('server account URI supplies the SDK login account name', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    Map? login;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'join') {
        login = call.arguments as Map;
        await emit('audioConnected');
      }
      return ['initialize', 'requestMicPermission'].contains(call.method)
          ? true
          : 0;
    });
    await voice.join('room', '');
    expect(login?['accountName'], '.issuer.user.');
    await voice.dispose();
  });
  test(
      'missing server configuration is actionable and does not start native login',
      () async {
    final methods = <String>[];
    final voice = VivoxVoiceService(
      tokenIssuer: (_) async => throw const FunctionException(
        status: 503,
        details: {'error': 'Vivox voice service is not configured'},
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });
    await expectLater(
      voice.join('room', ''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'diagnostic',
          contains('not configured (HTTP 503)'),
        ),
      ),
    );
    expect(methods, ['requestMicPermission']);
    await voice.dispose();
  });
  test('20122 is an invalid token signature, not a retryable network error', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'join') {
        await emit('error', status: 20122, detail: 'login');
        return 20122;
      }
      return ['initialize', 'requestMicPermission'].contains(call.method)
          ? true
          : 0;
    });
    await expectLater(
      voice.join('room', ''),
      throwsA(
        isA<VoiceConnectionFailure>()
            .having((e) => e.message.toString(), 'diagnostic',
                contains('invalid Vivox token signature'))
            .having((e) => e.message.toString(), 'admin action',
                contains('signing key'))
            .having((e) => e.message.toString(), 'no misleading retry',
                isNot(contains('Retry voice.'))),
      ),
    );
    await voice.dispose();
  });
  for (final stage in ['login', 'initial-mute', 'channel-join']) {
    test(
      'native $stage failure preserves its stage and status through cleanup',
      () async {
        final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'join') {
            await emit('error', status: 401, detail: stage);
            return 401;
          }
          return [
            'initialize',
            'requestMicPermission',
          ].contains(call.method)
              ? true
              : 0;
        });
        await expectLater(
          voice.join('room', ''),
          throwsA(
            isA<VoiceConnectionFailure>().having(
              (error) => error.message.toString(),
              'safe stage diagnostic',
              'Voice $stage failed (code 401). Retry voice.',
            ),
          ),
        );
        await voice.dispose();
      },
    );
  }
  for (final stage in [
    'requestMicPermission',
    'initialize',
    'join',
    'setMic',
  ]) {
    test('platform $stage failure is sanitized and identifies the method',
        () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == stage) {
          throw PlatformException(
            code: 'VIVOX_NATIVE',
            message: 'secret-token',
            details: {
              'type': 'UnsatisfiedLinkError',
              'payload': 'secret-token',
            },
          );
        }
        if (call.method == 'join') await emit('audioConnected');
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await expectLater(
        voice.join('room', ''),
        throwsA(
          isA<VoiceConnectionFailure>().having(
            (error) => error.message.toString(),
            'safe platform diagnostic',
            'Voice $stage failed (VIVOX_NATIVE, UnsatisfiedLinkError). Retry voice.',
          ),
        ),
      );
      if (stage == 'initialize') expect(methods, contains('shutdown'));
      await voice.dispose();
    });
  }
  test(
    'JNI missing callback identifies NoSuchMethodError without raw message',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') {
          throw PlatformException(
            code: 'VIVOX_NATIVE',
            message: 'secret-token',
            details: {'type': 'NoSuchMethodError'},
          );
        }
        return call.method == 'requestMicPermission' ? true : 0;
      });
      await expectLater(
        voice.join('room', ''),
        throwsA(
          isA<VoiceConnectionFailure>().having(
            (error) => error.message.toString(),
            'JNI diagnostic',
            'Voice initialize failed (VIVOX_NATIVE, NoSuchMethodError). Retry voice.',
          ),
        ),
      );
      await voice.dispose();
    },
  );
  test(
    'untrusted platform code and details never enter the diagnostic',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'secret-token',
          message: 'secret-token',
          details: {'type': 'secret-token'},
        );
      });
      await expectLater(
        voice.join('room', ''),
        throwsA(
          isA<VoiceConnectionFailure>().having(
            (error) => error.message.toString(),
            'safe fallback',
            'Voice requestMicPermission failed (PLATFORM). Retry voice.',
          ),
        ),
      );
      await voice.dispose();
    },
  );
  test(
    'media deadline begins after slow native login and join acceptance',
    () async {
      final voice = VivoxVoiceService(
        tokenIssuer: (_) async => credentials,
        connectionTimeout: const Duration(milliseconds: 10),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'join') {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          await emit('audioConnected');
        }
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await voice.join('room', '');
      await voice.dispose();
    },
  );
  test(
    'disconnect during a pending join fails immediately rather than timing out',
    () async {
      final voice = VivoxVoiceService(
        tokenIssuer: (_) async => credentials,
        connectionTimeout: const Duration(milliseconds: 20),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'join') await emit('audioDisconnected');
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await expectLater(voice.join('room', ''), throwsStateError);
      await voice.dispose();
    },
  );
  test('failed initialization retains the native status code', () async {
    final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') {
        await emit('error', status: 401);
        return false;
      }
      return call.method == 'requestMicPermission' ? true : 0;
    });
    await expectLater(
      voice.join('room', ''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'native status',
          contains('401'),
        ),
      ),
    );
    await voice.dispose();
  });
  test(
    'leave and rejoin recreate SDK state instead of reusing timed-out handles',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == 'join') await emit('audioConnected');
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await voice.join('room', '');
      await voice.leave();
      await voice.join('room', '');
      expect(methods.where((method) => method == 'initialize').length, 2);
      expect(methods, contains('shutdown'));
      await voice.dispose();
    },
  );
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
    expect(methods, contains('leave'));
    expect(methods.last, 'shutdown');
    await expectLater(voice.setMicEnabled(true), throwsStateError);
    await voice.dispose();
  });
  test(
    'audio dropping during initial mute cannot report a successful join',
    () async {
      final voice = VivoxVoiceService(tokenIssuer: (_) async => credentials);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'join') await emit('audioConnected');
        if (call.method == 'setMic') await emit('audioDisconnected');
        return ['initialize', 'requestMicPermission'].contains(call.method)
            ? true
            : 0;
      });
      await expectLater(voice.join('room', ''), throwsStateError);
      await voice.dispose();
    },
  );
  test('native error clears stale speaking indicators', () async {
    final voice = VivoxVoiceService();
    const id = 'c3d02bfb-a0f0-4ef9-b19f-10409dcb59af';
    final states = <Set<String>>[];
    final subscription = voice.speaking.listen(states.add);
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
    await emit('error', status: 500);
    await Future<void>.delayed(Duration.zero);
    expect(states, [
      {id},
      <String>{},
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
    expect(methods, contains('leave'));
    expect(methods.last, 'shutdown');
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
