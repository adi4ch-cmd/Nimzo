import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';

class EditorRepository extends MomentRepository {
  EditorRepository(super.db);
  int loads = 0;
  @override
  Future<Moment> get(String id) async {
    if (++loads == 1) throw StateError('Temporary failure');
    return Moment(
        id: id,
        authorId: 'author',
        text: 'Existing post',
        likes: 0,
        comments: 0,
        liked: false,
        createdAt: DateTime(2026));
  }
}

void main() {
  testWidgets('failed Moment load offers retry and recovers existing draft',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = EditorRepository(db);
    await tester.pumpWidget(ProviderScope(overrides: [
      momentRepositoryProvider.overrideWithValue(repo),
    ], child: const MaterialApp(home: CreateMomentScreen(id: 'post'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Existing post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
