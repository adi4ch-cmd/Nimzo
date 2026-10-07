import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:nimzo/core/services/storage_service.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
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

class PhotoStorage extends StorageService {
  PhotoStorage(super.db);
  ImageSource? selected;
  @override
  Future<String?> pickAndUpload(String bucket,
      {ImageSource source = ImageSource.gallery, String? roomId}) async {
    selected = source;
    return 'author/photo.jpg';
  }
}

class SaveRepository extends MomentRepository {
  SaveRepository(super.db);
  final pending = Completer<void>();
  @override
  Future<void> create({String? text, String? imagePath}) => pending.future;
}

void main() {
  testWidgets('Moment save refreshes feed even after editor is dismissed',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = SaveRepository(db);
    var loads = 0;
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('author'),
      momentRepositoryProvider.overrideWithValue(repo),
      momentsFeedProvider.overrideWith((_) async {
        loads++;
        return [];
      }),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(momentsFeedProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(momentsFeedProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreateMomentScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New post');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Moment photo chooser supports camera, preview and removal',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final storage = PhotoStorage(db);
    await tester.pumpWidget(ProviderScope(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      supabaseProvider.overrideWithValue(db),
    ], child: const MaterialApp(home: CreateMomentScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(storage.selected, ImageSource.camera);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Choose photo'), findsOneWidget);
  });

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
