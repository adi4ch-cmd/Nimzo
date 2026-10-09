import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

class UserPreferences {
  final bool messages, gifts, allowMessages;
  const UserPreferences({
    required this.messages,
    required this.gifts,
    required this.allowMessages,
  });
  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        messages: json['message_notifications'] as bool,
        gifts: json['gift_notifications'] as bool,
        allowMessages: json['allow_messages_from_everyone'] as bool,
      );
}

class UserPreferencesRepository {
  final SupabaseClient db;
  UserPreferencesRepository(this.db);
  Future<UserPreferences> get() async => UserPreferences.fromJson(
    Map<String, dynamic>.from(await db.rpc('user_settings')),
  );
  Future<UserPreferences> save(UserPreferences value) async =>
      UserPreferences.fromJson(
        Map<String, dynamic>.from(
          await db.rpc(
            'update_user_settings',
            params: {
              'p_message_notifications': value.messages,
              'p_gift_notifications': value.gifts,
              'p_allow_messages_from_everyone': value.allowMessages,
            },
          ),
        ),
      );
}

final userPreferencesRepositoryProvider = Provider(
  (ref) => UserPreferencesRepository(ref.watch(sessionSupabaseProvider).client),
);
final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesController, UserPreferences>(
      UserPreferencesController.new,
    );

class UserPreferencesController extends AsyncNotifier<UserPreferences> {
  int _generation = 0;
  @override
  Future<UserPreferences> build() {
    _generation++;
    return ref.watch(userPreferencesRepositoryProvider).get();
  }

  Future<void> change({
    bool? messages,
    bool? gifts,
    bool? allowMessages,
  }) async {
    final current = state.valueOrNull;
    if (state.isLoading || current == null) return;
    final generation = _generation;
    state = const AsyncLoading<UserPreferences>().copyWithPrevious(state);
    try {
      final saved = await ref
          .read(userPreferencesRepositoryProvider)
          .save(
            UserPreferences(
              messages: messages ?? current.messages,
              gifts: gifts ?? current.gifts,
              allowMessages: allowMessages ?? current.allowMessages,
            ),
          );
      if (generation == _generation) state = AsyncData(saved);
    } catch (_) {
      if (generation == _generation) state = AsyncData(current);
      rethrow;
    }
  }
}

class PreferenceControls extends ConsumerWidget {
  final bool privacy;
  const PreferenceControls({super.key, this.privacy = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(userPreferencesProvider);
    final current = value.valueOrNull;
    Future<void> change({
      bool? messages,
      bool? gifts,
      bool? allowMessages,
    }) async {
      try {
        await ref
            .read(userPreferencesProvider.notifier)
            .change(
              messages: messages,
              gifts: gifts,
              allowMessages: allowMessages,
            );
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings could not be saved. Retry.'),
            ),
          );
      }
    }

    if (current == null)
      return ListTile(
        title: const Text('Account preferences'),
        subtitle: Text(
          value.hasError ? 'Unable to load preferences.' : 'Loading…',
        ),
        trailing: value.hasError
            ? TextButton(
                onPressed: () => ref.invalidate(userPreferencesProvider),
                child: const Text('Retry'),
              )
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(),
              ),
      );
    if (privacy)
      return SwitchListTile(
        title: const Text('Allow private messages'),
        subtitle: const Text(
          'Turning this off blocks new incoming private messages.',
        ),
        value: current.allowMessages,
        onChanged: value.isLoading ? null : (v) => change(allowMessages: v),
      );
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: const Text('Message notifications'),
          value: current.messages,
          onChanged: value.isLoading ? null : (v) => change(messages: v),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('Gift notifications'),
          value: current.gifts,
          onChanged: value.isLoading ? null : (v) => change(gifts: v),
        ),
      ],
    );
  }
}
