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
  const Moment({required this.id, required this.authorId, this.text, this.imagePath, required this.likes,
      required this.comments, required this.liked, required this.createdAt});
  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
      id: j['id'], authorId: j['author_id'], text: j['body'], imagePath: j['image_path'],
      likes: (j['like_count'] ?? 0) as int, comments: (j['comment_count'] ?? 0) as int,
      liked: j['liked'] ?? false, createdAt: DateTime.parse(j['created_at']));
}

class MomentRepository {
  final SupabaseClient _db;
  MomentRepository(this._db);

  Future<List<Moment>> feed() async {
    try { return (await _db.rpc('moments_feed') as List).map((e) => Moment.fromJson(e)).toList(); }
    catch (e) { throw mapError(e); }
  }

  Future<Moment> get(String id) async {
    try {
      final row = await _db.from('moments').select().eq('id', id).single();
      return Moment.fromJson({...row, 'liked': false, 'like_count': 0, 'comment_count': 0});
    } catch (e) { throw mapError(e); }
  }

  Future<void> create({String? text, String? imagePath}) async {
    try { await _db.from('moments').insert({'author_id': _db.auth.currentUser!.id, 'body': text, 'image_path': imagePath}); }
    catch (e) { throw mapError(e); }
  }

  Future<void> update(String id, {String? text, String? imagePath}) async {
    try {
      await _db.from('moments').update({'body': text, 'image_path': imagePath}).eq('id', id).eq('author_id', _db.auth.currentUser!.id);
    } catch (e) { throw mapError(e); }
  }

  Future<void> toggleLike(String id) => _db.rpc('toggle_like', params: {'p_moment': id});
  Future<void> delete(String id) async { try { await _db.from('moments').delete().eq('id', id); } catch (e) { throw mapError(e); } }
  Future<void> report(String id, String reason) async {
    try { await _db.from('reports').insert({'reporter_id': _db.auth.currentUser!.id, 'target_type': 'moment', 'target_id': id, 'reason': reason}); }
    catch (e) { throw mapError(e); }
  }
  Future<List<Map<String, dynamic>>> comments(String id) async => await _db.from('moment_comments').select().eq('moment_id', id).order('created_at');
  Future<void> addComment(String id, String text) async {
    try { await _db.from('moment_comments').insert({'moment_id': id, 'author_id': _db.auth.currentUser!.id, 'body': text}); }
    catch (e) { throw mapError(e); }
  }

  Future<void> sendGift({required String momentId, required String receiverId, required String giftId, required int qty, required String key}) async {
    try {
      await _db.rpc('send_moment_gift', params: {
        'p_moment': momentId, 'p_receiver': receiverId, 'p_gift': giftId, 'p_qty': qty, 'p_key': key,
      });
    } catch (e) { throw mapError(e); }
  }
}

final momentRepositoryProvider = Provider((ref) => MomentRepository(ref.watch(supabaseProvider)));
final momentsFeedProvider = FutureProvider((ref) => ref.watch(momentRepositoryProvider).feed());
final commentsProvider = FutureProvider.family((ref, String id) => ref.watch(momentRepositoryProvider).comments(id));
