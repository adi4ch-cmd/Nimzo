import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

Message item(String id, int second) => Message(
    id: id,
    senderId: 'other',
    receiverId: 'me',
    kind: 'text',
    body: id,
    read: true,
    createdAt: DateTime.utc(2026, 10, 18, 0, 0, second));

class HistoryRepository extends MessageRepository {
  HistoryRepository(super.db);
  final pending = Completer<List<Message>>();
  int calls = 0;
  @override
  Future<List<Message>> older(String other, {required Message before}) {
    calls++;
    expect(before.id, 'middle');
    return pending.future;
  }
}

void main() {
  testWidgets('earlier messages load once and overlap is deduplicated',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = HistoryRepository(db);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      profileProvider('other')
          .overrideWith((_) async => const Profile(id: 'other', nimzoId: 123)),
      messageRepositoryProvider.overrideWithValue(repo),
      chatProvider('other').overrideWith(
          (_) => Stream.value([item('middle', 2), item('newest', 3)])),
    ], child: const MaterialApp(home: ConversationScreen(otherId: 'other'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-load-older')));
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('conversation-load-older')))
            .onPressed,
        isNull);
    expect(repo.calls, 1);
    repo.pending.complete([item('oldest', 1), item('middle', 2)]);
    await tester.pumpAndSettle();
    expect(find.text('oldest'), findsOneWidget);
    expect(find.text('middle'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-load-older')), findsNothing);
  });
}
