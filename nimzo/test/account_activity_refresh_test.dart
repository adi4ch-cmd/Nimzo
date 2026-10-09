import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/notifications/notification_repository.dart';

class Messages extends MessageRepository {
  Messages(super.db);
  final events = StreamController<int>.broadcast();
  int reads = 0;
  @override
  Stream<int> changes() => events.stream;
  @override
  Future<List<Map<String, dynamic>>> conversations() async => [
    {'unread': ++reads},
  ];
}

class Notices extends NotificationRepository {
  Notices(super.db);
  final events = StreamController<int>.broadcast();
  int reads = 0;
  @override
  Stream<int> changes() => events.stream;
  @override
  Future<List<Map<String, dynamic>>> list(String category) async => [
    {'id': ++reads},
  ];
}

void main() {
  test(
    'conversation activity reloads unread counts and cancels with container',
    () async {
      final db = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(db.dispose);
      final repo = Messages(db);
      final c = ProviderContainer(
        overrides: [messageRepositoryProvider.overrideWithValue(repo)],
      );
      final initial = await c.read(conversationsProvider.future);
      repo.events.add(1);
      await Future<void>.delayed(Duration.zero);
      final next = await c.read(conversationsProvider.future);
      expect(next.first['unread'], greaterThan(initial.first['unread'] as int));
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(repo.events.hasListener, false);
      await repo.events.close();
    },
  );
  test('notification events refresh multiple categories from the same authorized stream', () async {
    final db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(db.dispose);
    final repo = Notices(db);
    final c = ProviderContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await c.read(notificationsProvider('All').future);
    await c.read(notificationsProvider('Gifts').future);
    final previous = repo.reads;
    repo.events.add(1);
    await Future<void>.delayed(Duration.zero);
    await c.read(notificationsProvider('All').future);
    await c.read(notificationsProvider('Gifts').future);
    expect(repo.reads, previous + 2);
    c.dispose();
    await repo.events.close();
  });
}
