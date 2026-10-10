import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import '../../core/providers/supabase_provider.dart';
import 'profile.dart';
import '../moments/moment_repository.dart';

class ProfileRepository {
  final SupabaseClient _db;
  ProfileRepository(this._db);

  Future<Profile> get(String id) async {
    try {
      return Profile.fromJson(
        await _db.from('profiles').select().eq('id', id).single(),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> update({
    String? displayName,
    String? bio,
    String? avatarPath,
    String? coverPath,
    String? countryCode,
    String? countryName,
    String? language,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    try {
      final m = <String, dynamic>{
        if (displayName != null) 'display_name': displayName.trim(),
        if (bio != null) 'bio': bio,
        if (avatarPath != null) 'avatar_path': avatarPath,
        if (coverPath != null) 'cover_path': coverPath,
        if (countryCode != null) 'country_code': countryCode,
        if (countryName != null) 'country_name': countryName,
        if (language != null) 'language': language,
        if (dateOfBirth != null)
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        if (gender != null) 'gender': gender,
      };
      if (m.isEmpty) return;
      final id = _db.auth.currentUser?.id;
      if (id == null) throw StateError('Please sign in again.');
      final saved = await _db
          .from('profiles')
          .update(m)
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (saved == null)
        throw StateError('Profile was not saved. Please retry.');
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> recordVisit(String profileId) async {
    if (profileId == _db.auth.currentUser?.id) return;
    try {
      await _db.rpc('record_visit', params: {'p_profile': profileId});
    } catch (_) {}
  }

  Future<List<String>> tags(String id) async {
    final rows = await _db
        .from('profile_tags')
        .select('tag')
        .eq('user_id', id)
        .order('sort_order');
    return rows.map<String>((r) => r['tag'] as String).toList();
  }

  Future<Map<String, dynamic>?> couple(String id) async => await _db
      .from('couples')
      .select()
      .or('user_a.eq.$id,user_b.eq.$id')
      .maybeSingle();

  Future<List<Map<String, dynamic>>> models(String id) async => await _db
      .from('models')
      .select()
      .eq('user_id', id)
      .eq('active', true)
      .order('created_at', ascending: false);

  Future<List<Profile>> search(String q) async {
    try {
      final term = q.trim();
      if (term.isEmpty) return [];
      final id = int.tryParse(term);
      // Do not interpolate untrusted text into a PostgREST .or() filter.
      // The punctuation in that syntax could otherwise change the filter.
      final rows = id != null
          ? await _db.from('profiles').select().eq('nimzo_id', id).limit(20)
          : await _searchByName(term);
      return rows.map(Profile.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> _searchByName(String term) async {
    // Escape SQL LIKE wildcards so literal user input does not broaden results.
    final escaped = term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final usernameRows = await _db
        .from('profiles')
        .select()
        .ilike('username', '%$escaped%')
        .limit(20);
    final nameRows = await _db
        .from('profiles')
        .select()
        .ilike('display_name', '%$escaped%')
        .limit(20);
    final unique = <String, Map<String, dynamic>>{};
    for (final row in [...usernameRows, ...nameRows]) {
      unique[row['id'] as String] = row;
      if (unique.length >= 20) break;
    }
    return unique.values.toList();
  }

  Future<List<Map<String, dynamic>>> gifts(String id) async {
    final rows = await _db.rpc('profile_gifts', params: {'p_user': id});
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<List<String>> achievements(String id) async {
    final profile = await get(id);
    // Show only facts recorded on the profile; membership is not identity verification.
    return [
      if (profile.level > 1) 'Level ${profile.level}',
      if (profile.wealthLevel > 1) 'Wealth level ${profile.wealthLevel}',
      if (profile.charmLevel > 1) 'Charm level ${profile.charmLevel}',
      if (profile.activeLevel > 1) 'Activity level ${profile.activeLevel}',
      if (profile.vipLevel > 0) 'VIP level ${profile.vipLevel}',
      if (profile.svipLevel > 0) 'SVIP level ${profile.svipLevel}',
    ];
  }

  Future<Map<String, int>> stats(String id) async {
    final r = await _db.rpc('profile_stats', params: {'p_user': id});
    return Map<String, int>.from(
      (r as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())),
    );
  }
}

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(sessionSupabaseProvider).client),
);
final profileProvider = FutureProvider.family<Profile, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).get(id),
);
final profileStatsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).stats(id),
);
final profileTagsProvider = FutureProvider.family<List<String>, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).tags(id),
);
final profileCoupleProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).couple(id),
);
final profileModelsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).models(id),
);

final profileMomentsProvider = FutureProvider.family<List<Moment>, String>(
  (ref, id) => ref.watch(momentRepositoryProvider).byAuthor(id),
);
final profileGiftsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).gifts(id),
);
final profileAchievementsProvider = FutureProvider.family<List<String>, String>(
  (ref, id) => ref.watch(profileRepositoryProvider).achievements(id),
);
