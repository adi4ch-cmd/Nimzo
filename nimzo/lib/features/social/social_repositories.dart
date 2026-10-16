import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import '../../core/providers/supabase_provider.dart';

enum FriendState { none, sent, received, friends }

class FollowRepository {
  final SupabaseClient _db;
  FollowRepository(this._db);
  String get _me => _db.auth.currentUser!.id;
  Future<bool> isFollowing(String id) async =>
      await _db
          .from('follows')
          .select('followee_id')
          .eq('follower_id', _me)
          .eq('followee_id', id)
          .maybeSingle() !=
      null;
  Future<void> follow(String id) async {
    try {
      await _db.from('follows').insert({'follower_id': _me, 'followee_id': id});
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> unfollow(String id) async {
    try {
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', _me)
          .eq('followee_id', id);
    } catch (e) {
      throw mapError(e);
    }
  }
}

class FriendRepository {
  final SupabaseClient _db;
  FriendRepository(this._db);
  String get _me => _db.auth.currentUser!.id;

  Future<FriendState> state(String other) async {
    final rows = await _db.from('friendships').select().or(
          'and(requester_id.eq.$_me,addressee_id.eq.$other),and(requester_id.eq.$other,addressee_id.eq.$_me)',
        );
    if (rows.isEmpty) return FriendState.none;
    final r = rows.first;
    if (r['status'] == 'accepted') return FriendState.friends;
    return r['requester_id'] == _me ? FriendState.sent : FriendState.received;
  }

  Future<void> request(String id) async {
    try {
      await _db.from('friendships').insert({
        'requester_id': _me,
        'addressee_id': id,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> accept(String requester) async {
    try {
      await _db.rpc('accept_friend', params: {'p_requester': requester});
    } catch (e) {
      throw mapError(e);
    }
  }
}

class VisitorRepository {
  final SupabaseClient _db;
  VisitorRepository(this._db);
  Future<void> record(String profileId) =>
      _db.rpc('record_visit', params: {'p_profile': profileId});
  Future<List<Map<String, dynamic>>> mine() async => await _db
      .from('visitors')
      .select()
      .eq('profile_id', _db.auth.currentUser!.id)
      .order('visited_at', ascending: false)
      .limit(50);
}

class BlockRepository {
  final SupabaseClient _db;
  BlockRepository(this._db);
  String get _me => _db.auth.currentUser!.id;
  Future<void> block(String id) async {
    try {
      await _db.from('blocks').insert({'blocker_id': _me, 'blocked_id': id});
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> unblock(String id) async {
    try {
      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', _me)
          .eq('blocked_id', id);
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<String>> blocked() async =>
      (await _db.from('blocks').select('blocked_id').eq('blocker_id', _me))
          .map((r) => r['blocked_id'] as String)
          .toList();
}

final followRepositoryProvider = Provider(
  (ref) => FollowRepository(ref.watch(sessionSupabaseProvider).client),
);
final friendRepositoryProvider = Provider(
  (ref) => FriendRepository(ref.watch(sessionSupabaseProvider).client),
);
final visitorRepositoryProvider = Provider(
  (ref) => VisitorRepository(ref.watch(sessionSupabaseProvider).client),
);
final blockRepositoryProvider = Provider(
  (ref) => BlockRepository(ref.watch(sessionSupabaseProvider).client),
);
final isFollowingProvider = FutureProvider.family<bool, String>(
  (ref, id) => ref.watch(followRepositoryProvider).isFollowing(id),
);
final friendStateProvider = FutureProvider.family<FriendState, String>(
  (ref, id) => ref.watch(friendRepositoryProvider).state(id),
);
