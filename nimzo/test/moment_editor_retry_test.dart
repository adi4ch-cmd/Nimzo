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
      createdAt: DateTime(2026),
    );
  }
}

class PhotoStorage extends StorageService {
  PhotoStorage(super.db);
  ImageSource? selected;
  @override
  Future<String?> pickAndUpload(
    String bucket, {
    ImageSource source = ImageSource.gallery,
    String? roomId,
  }) async {
    selected = source;
    return 'author/photo.jpg';
  }
}

class SaveRepository extends MomentRepository {
  SaveRepository(super.db);
  final pending = Completer<void>();
  int creates = 0;
  @override
  Future<void> create({String? text, String? imagePath}) {
    creates++;
    return pending.future;
  }
}

void main() {
  testWidgets('Moment save refreshes feed even after editor is dismissed', (
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
    final repo = SaveRepository(db);
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('author'),
        momentRepositoryProvider.overrideWithValue(repo),
        momentsFeedProvider.overrideWith((_) async {
          loads++;
          return [];
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(momentsFeedProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(momentsFeedProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreateMomentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New post');
    // The user can publish through the visible reference AppBar action
    // even when the keyboard is open and the long draft scrolls below.
    expect(find.byKey(const ValueKey('moment-top-post')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('moment-top-post')));
    await tester.pump();
    expect(repo.creates, 1,
      reason: 'Post must initiate the real repository save before dismissal');
    await tester.pumpWidget(const SizedBox());
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Moment photo chooser supports camera, preview and removal', (
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
    final storage = PhotoStorage(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          supabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: CreateMomentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // The reference post editor scrolls below its header and multiline
    // caption field on a phone-sized viewport. A photo control below the
    // fold is not a missing action; reach it by scrolling like a user.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('moment-photo-picker')),
      190,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('moment-photo-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(storage.selected, ImageSource.camera);
    // This fixture returns a mocked storage path. Flutter tests cannot
    // fetch the generated public URL, so assert the real remove/edit
    // controls instead of treating a 400 network response as photo loss.
    await tester.scrollUntilVisible(
      find.text('Remove photo'),
      190,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Replace photo'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    // Removing the photo changes the scroll extent: scroll back to the
    // picker before verifying the restored Choose photo action.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('moment-photo-picker')), -140,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Choose photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('failed Moment load offers retry and recovers existing draft', (
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
    final repo = EditorRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: CreateMomentScreen(id: 'post')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Existing post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reference Moment topics and Mention edit the actual draft',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
      'https://example.supabase.co', 'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        momentRepositoryProvider.overrideWithValue(SaveRepository(db)),
      ],
      child: const MaterialApp(home: CreateMomentScreen()),
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextButton>(
        find.byKey(const ValueKey('moment-top-post'))).onPressed,
      isNull, reason: 'An empty reference Post action is disabled',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('moment-topic-#Bookworm')), 140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('moment-topic-#Bookworm')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('#Bookworm'),
    );
    expect(
      tester.widget<TextButton>(
        find.byKey(const ValueKey('moment-top-post'))).onPressed,
      isNotNull, reason: 'Typing a topic enables the real Post action',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('moment-mention-entry')));
    await tester.tap(find.byKey(const ValueKey('moment-mention-entry')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      endsWith('@'),
    );
    expect(tester.takeException(), isNull);
  });

}
