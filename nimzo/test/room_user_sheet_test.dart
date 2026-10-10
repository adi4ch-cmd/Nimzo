import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/levels_screen.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/data/room_repository.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/presentation/room_user_sheet.dart';
import 'package:nimzo/features/social/social_repositories.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

Future<void> render(
  WidgetTester tester, {
  required String me,
  String target = 'guest',
  bool asModal = false,
  bool moderator = false,
  RoomRepository? repository,
}) async {
  final sheet = RoomUserSheet(
    roomId: 'room',
    userId: target,
    seatNo: 2,
    muted: false,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          roomRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue(me),
        roomModerationProvider('room').overrideWith((_) async => moderator),
        giftCatalogProvider.overrideWith((_) async => []),
        walletProvider.overrideWith((_) async => (coins: 0, diamonds: 0)),
        roomProvider('room').overrideWith(
          (_) async => Room(
            id: 'room',
            roomNo: 123,
            name: 'Room',
            ownerId: 'owner',
            theme: 'nimzo_white',
            isPrivate: false,
            status: 'open',
            createdAt: DateTime(2026),
          ),
        ),
        profileProvider(target).overrideWith(
          (_) async => Profile(id: target, nimzoId: 100, displayName: 'Member'),
        ),
        isFollowingProvider(target).overrideWith((_) async => false),
        friendStateProvider(target).overrideWith((_) async => FriendState.none),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: asModal
              ? Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open seat'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => sheet,
                    ),
                  ),
                )
              : sheet,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final ban in [false, true]) {
    testWidgets('moderator ${ban ? 'ban' : 'kick'} confirms correct action', (
      tester,
    ) async {
      final repository = _ModerationRecorder();
      await render(
        tester,
        me: 'moderator',
        moderator: true,
        repository: repository,
      );
      await tester.tap(find.text(ban ? 'Ban from room' : 'Kick from room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ban ? 'Ban' : 'Remove'));
      await tester.pumpAndSettle();
      expect(repository.action, (room: 'room', user: 'guest', ban: ban));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non-owner server moderator sees separate kick and ban', (
    tester,
  ) async {
    await render(tester, me: 'moderator', moderator: true);
    expect(find.text('Kick from room'), findsOneWidget);
    expect(find.text('Ban from room'), findsOneWidget);
    expect(find.text('Mute seat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('moderator cannot remove owner', (tester) async {
    await render(tester, me: 'moderator', target: 'owner', moderator: true);
    expect(find.text('Kick from room'), findsNothing);
    expect(find.text('Ban from room'), findsNothing);
  });

  for (var kind = 0; kind < 3; kind++) {
    testWidgets('room badge $kind opens guest details on narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(tester, me: 'member');
      expect(find.text('—'), findsNWidgets(3));
      await tester.tap(find.byKey(ValueKey('room-user-level-$kind')));
      await tester.pumpAndSettle();
      final screen = tester.widget<LevelsScreen>(find.byType(LevelsScreen));
      expect(screen.initialKind, kind);
      expect(screen.userId, 'guest');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('seat sheet opens gift sheet with the app provider scope', (
    tester,
  ) async {
    await render(tester, me: 'member', asModal: true);
    await tester.tap(find.text('Open seat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send gift'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NIMZO Gifts'), findsOneWidget);
    expect(find.text('No gifts available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('member sheet shows real identity and supported social actions', (
    tester,
  ) async {
    await render(tester, me: 'member');
    expect(find.text('ID:100'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Add friend'), findsOneWidget);
    expect(find.text('Send gift'), findsOneWidget);
    expect(find.text('Kick from room'), findsNothing);
    expect(find.text('Ban from room'), findsNothing);
    expect(find.text('Mute seat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('room owner can see server-backed moderation actions', (
    tester,
  ) async {
    await render(tester, me: 'owner');
    expect(find.text('Kick from room'), findsOneWidget);
    expect(find.text('Mute seat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'own seat offers leave and self gifting without self social requests',
    (tester) async {
      await render(tester, me: 'guest');
      expect(find.text('Leave seat'), findsOneWidget);
      expect(find.text('Send gift'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
      expect(find.text('Add friend'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ModerationRecorder implements RoomRepository {
  ({String room, String user, bool ban})? action;
  @override
  Future<void> moderateMember(
    String roomId,
    String userId, {
    required bool ban,
  }) async {
    action = (room: roomId, user: userId, ban: ban);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
