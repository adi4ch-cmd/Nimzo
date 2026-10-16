import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

class SupportRepository {
  SupportRepository(this.client, this.userId);
  final SupabaseClient client;
  final String? userId;

  void _requireSession() {
    if (userId == null || client.auth.currentUser?.id != userId) {
      throw StateError('Sign in again before continuing.');
    }
  }

  Future<List<Map<String, dynamic>>> tickets() async {
    _requireSession();
    final rows = await client
        .from('support_tickets')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false)
        .limit(100);
    _requireSession();
    return rows;
  }

  Future<void> submit(String category, String subject, String body) async {
    _requireSession();
    await client.rpc(
      'submit_support_ticket',
      params: {
        'p_category': category,
        'p_subject': subject.trim(),
        'p_body': body.trim(),
      },
    );
    _requireSession();
  }

  Future<void> requestDeletion(String reason) async {
    _requireSession();
    await client.rpc(
      'request_account_deletion',
      params: {'p_reason': reason.trim()},
    );
    _requireSession();
  }
}

final supportRepositoryProvider = Provider((ref) {
  final session = ref.watch(sessionSupabaseProvider);
  return SupportRepository(session.client, session.userId);
});
final supportTicketsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(supportRepositoryProvider).tickets(),
);
