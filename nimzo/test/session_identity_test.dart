import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';

void main() {
  test(
      'identity follows session changes rather than retaining the first account',
      () async {
    final db = SupabaseClient('https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final events = StreamController<String?>();
    addTearDown(events.close);
    final container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(db),
      sessionUserIdProvider.overrideWith((ref) => events.stream)
    ]);
    addTearDown(container.dispose);
    final seen = <String?>[];
    container.listen(currentUserIdProvider, (_, id) => seen.add(id),
        fireImmediately: true);
    for (final id in <String?>['first', 'second', null]) {
      events.add(id);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(container.read(currentUserIdProvider), id);
    }
    expect(seen, containsAllInOrder(['first', 'second', null]));
    expect(container.read(currentUserIdProvider), isNull);
  });
}
