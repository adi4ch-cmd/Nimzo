import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/social/blocked_users_screen.dart';
import 'package:nimzo/features/social/social_repositories.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/discover/ranking_screen.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';

class Blocks extends BlockRepository {
  Blocks(super.db);
  List<String> ids = ['other'];
  final pending = Completer<void>();
  int calls = 0;
  bool fail = false;
  @override
  Future<List<String>> blocked() async => List.of(ids);
  @override
  Future<void> unblock(String id) async {
    calls++;
    await pending.future;
    if (fail) throw StateError('test failure');
    ids.remove(id);
  }
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
        'unblock ${fail ? 'failure preserves list' : 'success refreshes list'} prevents duplicate requests',
        (tester) async {
      final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co', 'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final repo = Blocks(db)..fail = fail;
      await tester.pumpWidget(ProviderScope(overrides: [
        blockRepositoryProvider.overrideWithValue(repo),
        profileProvider('other').overrideWith((_) async => const Profile(
            id: 'other', nimzoId: 100005, displayName: 'Actual user')),
      ], child: const MaterialApp(home: BlockedUsersScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Actual user'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pump();
      await tester.tap(find.text('Unblocking…'));
      expect(repo.calls, 1);
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(
          find.text(fail
              ? 'Unable to unblock this user. Retry.'
              : 'No blocked users.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'ranking opens authoritative Wealth weekly instead of unsupported blank default',
      (tester) async {
    final requests = <(String, String)>[];
    await tester.pumpWidget(ProviderScope(overrides: [
      leaderboardProvider.overrideWith((ref, key) async {
        requests.add(key);
        return [];
      }),
    ], child: const MaterialApp(home: RankingScreen())));
    await tester.pumpAndSettle();
    expect(requests, [('wealth', 'weekly')]);
    expect(find.text('No rankings yet'), findsOneWidget);
    expect(find.text('This ranking is unavailable.'), findsNothing);
  });
}
