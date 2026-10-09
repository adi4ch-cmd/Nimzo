import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/settings/settings_screen.dart';
import 'package:nimzo/features/auth/presentation/auth_controller.dart';
import 'package:nimzo/features/voice/voice_service.dart';
import 'package:nimzo/features/voice/voice_controller.dart';

class LogoutController extends AuthController {
  bool signedOut = false;
  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class FailedVoice implements VoiceService {
  @override
  Future<void> leave() async => throw StateError('Native error');
  @override
  Future<void> join(String id, String token) async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setMicEnabled(bool enabled) async {}
  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}
  @override
  Stream<bool> get connected => const Stream.empty();
  @override
  Stream<Set<String>> get speaking => const Stream.empty();
}

void main() {
  testWidgets('native voice leave failure does not prevent session logout',
      (tester) async {
    final auth = LogoutController();
    await tester.pumpWidget(ProviderScope(overrides: [
      authControllerProvider.overrideWith(() => auth),
      voiceServiceProvider.overrideWithValue(FailedVoice()),
    ], child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, true);
  });
}
