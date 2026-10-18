import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/notifications/notification_repository.dart';
import 'package:nimzo/features/notifications/notifications_screen.dart';

class OpeningNotices extends NotificationRepository {
  OpeningNotices(super.db);
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> markRead(String id) {
    calls++;
    return pending.future;
  }

  @override
  Future<List<Map<String, dynamic>>> list(String category) async => [
        {
          'id': 'notice',
          'title': 'New follower',
          'body': 'Open activity',
          'event_type': 'follow',
          'actor_id': 'other',
          'category': 'followers',
        }
      ];
}

void main() {
  testWidgets('notification opens the actor once after read confirmation',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repository = OpeningNotices(db);
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/profile/:id',
          builder: (_, s) =>
              Scaffold(body: Text('Profile ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      notificationRepositoryProvider.overrideWithValue(repository)
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New follower'));
    await tester.pump();
    await tester.tap(find.text('New follower'));
    await tester.pump();
    expect(repository.calls, 1);
    expect(router.routeInformationProvider.value.uri.path, '/notifications');
    repository.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Profile other'), findsOneWidget);
  });
}
