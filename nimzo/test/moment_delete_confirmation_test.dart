import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

class DeleteRecorder extends MomentRepository {
  DeleteRecorder(super.db);
  final deleted = <String>[];
  @override
  Future<void> delete(String id) async {
    deleted.add(id);
  }
}

void main() {
  testWidgets('own Moment deletion requires explicit confirmation', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = DeleteRecorder(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('author'),
          profileProvider('author').overrideWith(
            (_) async => const Profile(
              id: 'author',
              nimzoId: 123,
              displayName: 'Author',
            ),
          ),
          momentRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MomentCard(
              moment: Moment(
                id: 'moment',
                authorId: 'author',
                text: 'Own post',
                likes: 0,
                comments: 0,
                liked: false,
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['moment']);
    expect(tester.takeException(), isNull);
  });
}
