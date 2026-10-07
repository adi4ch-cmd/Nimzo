import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import '../../core/providers/supabase_provider.dart';

class Moment {
  final String id, authorId;
  final String? text, imagePath;
  final int likes, comments;
  final bool liked;
  final DateTime createdAt;
  const Moment({
    required this.id,
    required this.authorId,
    this.text,
    this.imagePath,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.createdAt,
  });
  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'],
        authorId: j['author_id'],
        text: j['body'],
        imagePath: j['image_path'],
        likes: (j['like_count'] as num?)?.toInt() ?? 0,
        comments: (j['comment_count'] as num?)?.toInt() ?? 0,
        liked: j['liked'] ?? false,
        createdAt: DateTime.parse(j['created_at']),
      );
}

class MomentRepository {
  final SupabaseClient _db;
  MomentRepository(this._db);

  Future<List<Moment>> feed() async {
    try {
      return (await _db.rpc('moments_feed') as List)
          .map((e) => Moment.fromJson(e))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Moment>> byAuthor(String authorId) async {
    try {
      final rows = await _db
          .from('moments')
          .select('id')
          .eq('author_id', authorId)
          .order('created_at', ascending: false)
          .limit(50);
      return await Future.wait(rows.map((row) => get(row['id'] as String)));
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Moment> get(String id) async {
    try {
      final row = await _db.from('moments').select().eq('id', id).single();
      final counts = await Future.wait([
        _db.from('moment_likes').count(CountOption.exact).eq('moment_id', id),
        _db
            .from('moment_comments')
            .count(CountOption.exact)
            .eq('moment_id', id),
      ]);
      final userId = _db.auth.currentUser?.id;
      final like = userId == null
          ? null
          : await _db
              .from('moment_likes')
              .select('user_id')
              .eq('moment_id', id)
              .eq('user_id', userId)
              .maybeSingle();
      return Moment.fromJson({
        ...row,
        'liked': like != null,
        'like_count': counts[0],
        'comment_count': counts[1],
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> create({String? text, String? imagePath}) async {
    try {
      await _db.from('moments').insert({
        'author_id': _db.auth.currentUser!.id,
        'body': text,
        'image_path': imagePath,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> update(String id, {String? text, String? imagePath}) async {
    try {
      await _db
          .from('moments')
          .update({'body': text, 'image_path': imagePath})
          .eq('id', id)
          .eq('author_id', _db.auth.currentUser!.id)
          .select('id')
          .single();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> toggleLike(String id) =>
      _db.rpc('toggle_like', params: {'p_moment': id});
  Future<void> delete(String id) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw StateError('Please sign in again.');
      await _db
          .from('moments')
          .delete()
          .eq('id', id)
          .eq('author_id', uid)
          .select('id')
          .single();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> report(String id, String reason) async {
    try {
      await _db.from('reports').insert({
        'reporter_id': _db.auth.currentUser!.id,
        'target_type': 'moment',
        'target_id': id,
        'reason': reason,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> comments(String id) async => await _db
      .from('moment_comments')
      .select()
      .eq('moment_id', id)
      .order('created_at');
  Future<void> addComment(String id, String text) async {
    try {
      await _db.from('moment_comments').insert({
        'moment_id': id,
        'author_id': _db.auth.currentUser!.id,
        'body': text,
      });
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> sendGift({
    required String momentId,
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {
    try {
      await _db.rpc(
        'send_moment_gift',
        params: {
          'p_moment': momentId,
          'p_receiver': receiverId,
          'p_gift': giftId,
          'p_qty': qty,
          'p_key': key,
        },
      );
    } catch (e) {
      throw mapError(e);
    }
  }
}

final momentRepositoryProvider = Provider(
  (ref) => MomentRepository(ref.watch(sessionSupabaseProvider).client),
);
final momentsFeedProvider = FutureProvider(
  (ref) => ref.watch(momentRepositoryProvider).feed(),
);
final commentsProvider = FutureProvider.family(
  (ref, String id) => ref.watch(momentRepositoryProvider).comments(id),
);
