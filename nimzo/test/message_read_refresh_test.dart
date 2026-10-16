import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

class ReadRepository extends MessageRepository {
  ReadRepository(super.db);
  @override
  Future<void> markRead(String other) async {}
}

void main() {
  testWidgets(
    'successful server mark-read refreshes conversation unread counts',
    (tester) async {
      final db = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ))!;
      addTearDown(() => tester.runAsync(db.dispose));
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('viewer'),
          messageRepositoryProvider.overrideWithValue(ReadRepository(db)),
          profileProvider(
            'other',
          ).overrideWith((_) async => const Profile(id: 'other', nimzoId: 1)),
          conversationsProvider.overrideWith((_) async {
            loads++;
            return [];
          }),
          chatProvider('other').overrideWith(
            (_) => Stream.value([
              Message(
                id: 'message',
                senderId: 'other',
                receiverId: 'viewer',
                kind: 'text',
                body: 'Incoming',
                read: false,
                createdAt: DateTime(2026),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(conversationsProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(conversationsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConversationScreen(otherId: 'other')),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
