import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vivox_voice_service.dart';
import 'voice_service.dart';

/// Swap this provider to migrate to your own voice server.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final s = VivoxVoiceService();
  final auth = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
    if (event.session == null) unawaited(s.leave().catchError((_) {}));
  });
  ref.onDispose(() {
    unawaited(auth.cancel());
    unawaited(s.dispose().catchError((_) {}));
  });
  return s;
});

final speakingProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(voiceServiceProvider).speaking,
);

final voiceConnectedProvider = StreamProvider<bool>(
  (ref) => ref.watch(voiceServiceProvider).connected,
);
