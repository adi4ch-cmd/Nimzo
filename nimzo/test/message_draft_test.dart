import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';

class SendingRepository extends MessageRepository {
  SendingRepository(super.db);
  final pending = Completer<void>();
  @override
  Future<void> send(String to, String body, {String kind = 'text'}) =>
      pending.future;
  @override
  Future<void> markRead(String other) async {}
}

void main() {
  testWidgets(
      'sending a message preserves the next draft typed before response',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = SendingRepository(db);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('viewer'),
      messageRepositoryProvider.overrideWithValue(repo),
      chatProvider('other').overrideWith((_) => Stream.value([])),
      conversationsProvider.overrideWith((_) async => []),
    ], child: const MaterialApp(home: ConversationScreen(otherId: 'other'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Second draft');
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Second draft');
    expect(tester.takeException(), isNull);
  });
}
