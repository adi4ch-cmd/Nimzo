import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

class CommentRecorder extends MomentRepository {
  CommentRecorder(super.db);
  final pending = Completer<void>();
  final sent = <String>[];
  @override
  Future<void> addComment(String id, String text) {
    sent.add(text);
    return pending.future;
  }
}

void main() {
  final moment = Moment(
      id: 'post',
      authorId: 'author',
      text: 'Post',
      likes: 0,
      comments: 0,
      liked: false,
      createdAt: DateTime(2026));
  for (final leave in [false, true]) {
    testWidgets(
        leave
            ? 'comment completion after leaving refreshes feed safely'
            : 'comment completion preserves a newer draft and refreshes feed',
        (tester) async {
      final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final repo = CommentRecorder(db);
      var feedLoads = 0;
      var profileLoads = 0;
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue('viewer'),
        profileProvider('author').overrideWith((_) async =>
            const Profile(id: 'author', nimzoId: 123, displayName: 'Author')),
        momentRepositoryProvider.overrideWithValue(repo),
        momentDetailProvider('post').overrideWith((_) async => moment),
        commentsProvider('post').overrideWith((_) async => []),
        momentsFeedProvider.overrideWith((_) async {
          feedLoads++;
          return [moment];
        }),
        profileMomentsProvider('author').overrideWith((_) async {
          profileLoads++;
          return [moment];
        }),
      ]);
      addTearDown(container.dispose);
      final subscription = container.listen(momentsFeedProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(momentsFeedProvider.future);
      final profileSubscription =
          container.listen(profileMomentsProvider('author'), (_, __) {});
      addTearDown(profileSubscription.close);
      await container.read(profileMomentsProvider('author').future);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MomentDetailScreen(id: 'post'))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ' First comment ');
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pump();
      expect(repo.sent, ['First comment']);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      if (leave) {
        await tester.pumpWidget(const SizedBox());
      } else {
        await tester.enterText(find.byType(TextField), 'Next draft');
      }
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(feedLoads, 2);
      expect(profileLoads, 2);
      expect(find.text('Comment could not be sent.'), findsNothing);
      if (!leave) {
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Next draft');
      }
    });
  }
}
