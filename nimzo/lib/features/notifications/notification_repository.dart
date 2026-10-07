import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

const notificationCategories = [
  'All',
  'Messages',
  'Gifts',
  'Followers',
  'Friends',
  'Rooms',
  'VIP',
  'SVIP',
  'System',
];

/// Supabase stores notifications; FCM only delivers the push.
class NotificationRepository {
  final SupabaseClient _db;
  NotificationRepository(this._db);
  Future<List<Map<String, dynamic>>> list(String category) async {
    var q = _db.from('notifications').select();
    if (category != 'All') q = q.eq('category', category.toLowerCase());
    return await q.order('created_at', ascending: false).limit(100);
  }

  Future<void> markAllRead() => _db.rpc('mark_notifications_read');
  Future<void> registerDevice(String token) =>
      _db.rpc('register_device', params: {'p_token': token});
}

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(sessionSupabaseProvider).client),
);
final notificationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, c) => ref.watch(notificationRepositoryProvider).list(c),
);
