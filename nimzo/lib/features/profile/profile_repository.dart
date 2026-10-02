import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/error_handler.dart';
import '../../core/providers/supabase_provider.dart';
import 'profile.dart';

class ProfileRepository {
  final SupabaseClient _db;
  ProfileRepository(this._db);

  Future<Profile> get(String id) async {
    try { return Profile.fromJson(await _db.from('profiles').select().eq('id', id).single()); }
    catch (e) { throw mapError(e); }
  }

  Future<void> update({String? displayName, String? bio, String? avatarPath, String? coverPath, String? countryCode,
      String? countryName, String? language, DateTime? dateOfBirth, String? gender}) async {
    try {
      final m = <String, dynamic>{
        if (displayName != null) 'display_name': displayName.trim(),
        if (bio != null) 'bio': bio,
        if (avatarPath != null) 'avatar_path': avatarPath,
        if (coverPath != null) 'cover_path': coverPath,
        if (countryCode != null) 'country_code': countryCode,
        if (countryName != null) 'country_name': countryName,
        if (language != null) 'language': language,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        if (gender != null) 'gender': gender,
      };
      if (m.isEmpty) return;
      await _db.from('profiles').update(m).eq('id', _db.auth.currentUser!.id);
    } catch (e) { throw mapError(e); }
  }

  Future<void> recordVisit(String profileId) async {
    if (profileId == _db.auth.currentUser?.id) return;
    try { await _db.rpc('record_visit', params: {'p_profile': profileId}); } catch (_) {}
  }

  Future<List<String>> tags(String id) async {
    final rows = await _db.from('profile_tags').select('tag').eq('user_id', id).order('sort_order');
    return rows.map<String>((r) => r['tag'] as String).toList();
  }

  Future<Map<String, dynamic>?> couple(String id) async =>
      await _db.from('couples').select().or('user_a.eq.$id,user_b.eq.$id').maybeSingle();

  Future<List<Map<String, dynamic>>> models(String id) async =>
      await _db.from('models').select().eq('user_id', id).eq('active', true).order('created_at', ascending: false);

  Future<List<Profile>> search(String q) async {
    try {
      final id = int.tryParse(q);
      final rows = id != null
          ? await _db.from('profiles').select().eq('nimzo_id', id).limit(20)
          : await _db.from('profiles').select().ilike('country_name', '%$q%').limit(20);
      return rows.map(Profile.fromJson).toList();
    } catch (e) { throw mapError(e); }
  }

  Future<Map<String, int>> stats(String id) async {
    final r = await _db.rpc('profile_stats', params: {'p_user': id});
    return Map<String, int>.from((r as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())));
  }
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseProvider)));
final profileProvider = FutureProvider.family<Profile, String>((ref, id) => ref.watch(profileRepositoryProvider).get(id));
final profileStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, id) => ref.watch(profileRepositoryProvider).stats(id));
final profileTagsProvider = FutureProvider.family<List<String>, String>((ref, id) => ref.watch(profileRepositoryProvider).tags(id));
final profileCoupleProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) => ref.watch(profileRepositoryProvider).couple(id));
final profileModelsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) => ref.watch(profileRepositoryProvider).models(id));
