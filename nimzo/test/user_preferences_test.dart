import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/settings/user_preferences.dart';

class Preferences extends UserPreferencesRepository {
  Preferences(super.db);
  UserPreferences current = const UserPreferences(
    messages: true,
    gifts: true,
    allowMessages: true,
  );
  final pending = Completer<UserPreferences>();
  int saves = 0;
  @override
  Future<UserPreferences> get() async => current;
  @override
  Future<UserPreferences> save(UserPreferences value) async {
    saves++;
    return pending.future;
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'preferences ${fail ? 'preserve confirmed values on failure' : 'persist server response'} and serialize saves',
      () async {
        final db = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(db.dispose);
        final repo = Preferences(db);
        final c = ProviderContainer(
          overrides: [
            userPreferencesRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(c.dispose);
        await c.read(userPreferencesProvider.future);
        final saving = c
            .read(userPreferencesProvider.notifier)
            .change(gifts: false);
        await c.read(userPreferencesProvider.notifier).change(messages: false);
        expect(repo.saves, 1);
        if (fail) {
          repo.pending.completeError(StateError('fixture'));
          await expectLater(saving, throwsStateError);
        } else {
          repo.pending.complete(
            const UserPreferences(
              messages: true,
              gifts: false,
              allowMessages: true,
            ),
          );
          await saving;
        }
        expect(c.read(userPreferencesProvider).requireValue.gifts, fail);
        expect(c.read(userPreferencesProvider).requireValue.messages, true);
      },
    );
  }
  test(
    'late save cannot replace preferences after account repository changes',
    () async {
      final db = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(db.dispose);
      final first = Preferences(db),
          second = Preferences(db)
            ..current = const UserPreferences(
              messages: false,
              gifts: false,
              allowMessages: false,
            );
      final identity = StateProvider<bool>((_) => false);
      final c = ProviderContainer(
        overrides: [
          userPreferencesRepositoryProvider.overrideWith(
            (ref) => ref.watch(identity) ? second : first,
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(userPreferencesProvider.future);
      final saving = c
          .read(userPreferencesProvider.notifier)
          .change(gifts: false);
      c.read(identity.notifier).state = true;
      await c.read(userPreferencesProvider.future);
      first.pending.complete(
        const UserPreferences(messages: true, gifts: true, allowMessages: true),
      );
      await saving;
      expect(c.read(userPreferencesProvider).requireValue.messages, false);
      expect(c.read(userPreferencesProvider).requireValue.allowMessages, false);
    },
  );
}
