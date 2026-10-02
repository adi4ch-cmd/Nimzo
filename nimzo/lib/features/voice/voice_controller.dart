import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vivox_voice_service.dart';
import 'voice_service.dart';

/// Swap this provider to migrate to your own voice server.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final s = VivoxVoiceService();
  ref.onDispose(s.dispose);
  return s;
});

final speakingProvider = StreamProvider<Set<String>>(
    (ref) => ref.watch(voiceServiceProvider).speaking);
