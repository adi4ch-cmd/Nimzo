import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

class NimzoFamily {
  const NimzoFamily(
      {required this.id,
      required this.ownerId,
      required this.name,
      required this.description,
      required this.memberIds});
  final String id, ownerId, name, description;
  final List<String> memberIds;
  int get memberCount => memberIds.length + 1;
  bool includes(String? user) => ownerId == user || memberIds.contains(user);
  factory NimzoFamily.fromJson(Map<String, dynamic> row) => NimzoFamily(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        memberIds: [
          for (final member in row['nimzo_family_members'] as List? ?? [])
            member['user_id'] as String
        ],
      );
}

class FamilyRepository {
  FamilyRepository(this.db);
  final SupabaseClient db;
  String get me =>
      db.auth.currentUser?.id ?? (throw StateError('Sign in required'));
  Future<List<NimzoFamily>> directory() async {
    const fields = 'id,owner_id,name,description,nimzo_family_members(user_id)';
    final user = me;
    final results = await Future.wait([
      db
          .from('nimzo_families')
          .select(fields)
          .order('created_at', ascending: false)
          .limit(100),
      db.from('nimzo_families').select(fields).eq('owner_id', user),
      db
          .from('nimzo_family_members')
          .select('nimzo_families($fields)')
          .eq('user_id', user),
    ]);
    final families = <String, NimzoFamily>{};
    // Pin the user's families even when the public directory has newer entries.
    for (final row in results[1]) {
      final family = NimzoFamily.fromJson(row);
      families[family.id] = family;
    }
    for (final row in results[2]) {
      final nested = row['nimzo_families'];
      if (nested is Map<String, dynamic>) {
        final family = NimzoFamily.fromJson(nested);
        families[family.id] = family;
      }
    }
    for (final row in results[0]) {
      final family = NimzoFamily.fromJson(row);
      families.putIfAbsent(family.id, () => family);
    }
    return families.values.toList();
  }

  String newRequestKey() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

  Future<void> create(
      String name, String description, String requestKey) async {
    final result = await db.rpc('create_family', params: {
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_key': requestKey,
    });
    if (result is! Map || result['created'] != true) {
      throw StateError('Family creation could not be verified');
    }
  }

  Future<void> join(String id) async {
    // The composite key makes repeated joins harmless.
    try {
      await db
          .from('nimzo_family_members')
          .insert({'family_id': id, 'user_id': me});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> leave(String id) async {
    await db
        .from('nimzo_family_members')
        .delete()
        .eq('family_id', id)
        .eq('user_id', me);
  }
}

final familyRepositoryProvider = Provider(
    (ref) => FamilyRepository(ref.watch(sessionSupabaseProvider).client));
final familyDirectoryProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(familyRepositoryProvider).directory());
