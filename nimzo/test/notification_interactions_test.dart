import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/notifications/notification_repository.dart';
import 'package:nimzo/features/notifications/notifications_screen.dart';

class NoticeRepository extends NotificationRepository {
  NoticeRepository(super.db);
  final categories = <String>[];
  bool read = false;
  @override
  Future<List<Map<String, dynamic>>> list(String category) async {
    categories.add(category);
    return [
      {
        'title': 'Actual notice',
        'body': 'Body',
        'read_at': read ? '2026-10-08' : null
      }
    ];
  }

  @override
  Future<void> markAllRead() async {
    read = true;
  }
}

void main() {
  testWidgets('notification category and read action reload server-backed rows',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = NoticeRepository(db);
    await tester.pumpWidget(ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NotificationsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gifts'));
    await tester.pumpAndSettle();
    expect(repo.categories, ['All', 'Gifts']);
    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();
    expect(repo.read, true);
    expect(repo.categories.last, 'Gifts');
    expect(repo.categories.where((c) => c == 'Gifts').length, 2);
    expect(tester.takeException(), isNull);
  });
}
