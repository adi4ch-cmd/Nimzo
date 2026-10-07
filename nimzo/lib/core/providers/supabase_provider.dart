import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
final currentUserIdProvider = Provider<String?>(
  (ref) {
    final identity = ref.watch(sessionUserIdProvider);
    return identity.hasValue
        ? identity.valueOrNull
        : ref.watch(supabaseProvider).auth.currentUser?.id;
  },
);

final sessionUserIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((event) => event.session?.user.id);
});

/// Rebuild data repositories on account transitions so cached data cannot cross accounts.
final sessionSupabaseProvider =
    Provider<({SupabaseClient client, String? userId})>((ref) => (
          client: ref.watch(supabaseProvider),
          userId: ref.watch(currentUserIdProvider),
        ));
