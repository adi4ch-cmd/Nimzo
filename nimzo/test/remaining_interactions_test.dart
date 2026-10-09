import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/providers/ui_language_provider.dart';
import 'package:nimzo/features/social/friend_button.dart';
import 'package:nimzo/features/social/social_repositories.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/settings/language_choices.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/moments/moment_repository.dart';

class PendingFriend extends FriendRepository {
  PendingFriend(super.db);
  final pending = Completer<void>();
  int requests = 0;
  FriendState current = FriendState.none;
  @override
  Future<FriendState> state(String id) async => current;
  @override
  Future<void> request(String id) async {
    requests++;
    await pending.future;
    current = FriendState.sent;
  }
}

class PendingLanguage extends ProfileRepository {
  PendingLanguage(super.db);
  final pending = Completer<void>();
  String? submitted;
  @override
  Future<void> update(
      {String? displayName,
      String? bio,
      String? avatarPath,
      String? coverPath,
      String? countryCode,
      String? countryName,
      String? language,
      DateTime? dateOfBirth,
      String? gender}) async {
    submitted = language;
    await pending.future;
  }
}

Future<SupabaseClient> client(WidgetTester tester) async {
  final db = (await tester.runAsync(() async => SupabaseClient(
      'https://example.supabase.co', 'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
  addTearDown(() => tester.runAsync(db.dispose));
  return db;
}

void main() {
  test('UI language resets when the signed-in identity changes', () {
    final identity = StateProvider<String?>((_) => 'first');
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(identity)),
    ]);
    addTearDown(container.dispose);
    container.read(uiLanguageProvider.notifier).state = 'ar';
    expect(container.read(uiLanguageProvider), 'ar');
    container.read(identity.notifier).state = null;
    expect(container.read(uiLanguageProvider), 'en');
    container.read(identity.notifier).state = 'second';
    expect(container.read(uiLanguageProvider), 'en');
  });
  testWidgets(
      'confirmed friend request refreshes state after leaving the profile',
      (tester) async {
    final repo = PendingFriend(await client(tester));
    final container = ProviderContainer(
        overrides: [friendRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(body: ReferenceFriendButton(userId: 'recipient')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(await container.read(friendStateProvider('recipient').future),
        FriendState.sent);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'friend request prevents duplicate taps and waits for confirmation',
      (tester) async {
    final repo = PendingFriend(await client(tester));
    await tester.pumpWidget(ProviderScope(
        overrides: [friendRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
            home: Scaffold(body: ReferenceFriendButton(userId: 'recipient')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Friend'));
    await tester.pump();
    expect(find.text('Requested'), findsNothing);
    expect(repo.requests, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Requested'), findsOneWidget);
  });
  testWidgets(
      'language remains unchanged until the existing profile save confirms',
      (tester) async {
    final repo = PendingLanguage(await client(tester));
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      profileRepositoryProvider.overrideWithValue(repo)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LanguageChoices()))));
    await tester.tap(find.text('العربية'));
    await tester.pump();
    expect(repo.submitted, 'ar');
    expect(container.read(uiLanguageProvider), 'en');
    repo.pending.complete();
    await tester.pumpAndSettle();
    expect(container.read(uiLanguageProvider), 'ar');
  });
  testWidgets(
      'failed language save retains the confirmed language and offers retry',
      (tester) async {
    final repo = PendingLanguage(await client(tester));
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      profileRepositoryProvider.overrideWithValue(repo)
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LanguageChoices()))));
    await tester.tap(find.text('العربية'));
    await tester.pump();
    repo.pending.completeError(StateError('Rejected'));
    await tester.pumpAndSettle();
    expect(container.read(uiLanguageProvider), 'en');
    expect(find.text('Language could not be saved. Retry.'), findsOneWidget);
  });
  testWidgets(
      'broadcast uses supplied server callback once and preserves failure draft',
      (tester) async {
    final pending = Completer<void>();
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RoomToolForm(
                tool: 'Broadcast',
                onAnnounce: (body) {
                  calls.add(body);
                  return pending.future;
                }))));
    await tester.enterText(find.byType(TextField), 'Hello room');
    await tester.tap(find.text('Send to room'));
    await tester.pump();
    expect(calls, ['Broadcast · Hello room']);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    pending.completeError(StateError('Rejected'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello room');
    expect(find.text('Room action could not be completed. Retry.'),
        findsOneWidget);
  });
  testWidgets(
      'feed comment action opens reference sheet with live comment identity',
      (tester) async {
    final moment = Moment(
        id: 'post',
        authorId: 'author',
        text: 'Post',
        likes: 1,
        comments: 1,
        liked: false,
        createdAt: DateTime(2026));
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      profileProvider('author').overrideWith((_) async =>
          const Profile(id: 'author', nimzoId: 1, displayName: 'Author')),
      profileProvider('me').overrideWith((_) async =>
          const Profile(id: 'me', nimzoId: 2, displayName: 'Viewer')),
      commentsProvider('post').overrideWith((_) async => [
            {'author_id': 'me', 'body': 'Actual comment'}
          ]),
    ], child: MaterialApp(home: Scaffold(body: MomentCard(moment: moment)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comment 1'));
    await tester.pumpAndSettle();
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Actual comment'), findsOneWidget);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
