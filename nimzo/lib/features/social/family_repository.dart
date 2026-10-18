import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

/// A live, RLS-filtered family directory row from PostgreSQL.
/// No family names, counts, avatars or coin balances are fabricated on device.
class NimzoFamily {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String ownerName;
  final String? ownerAvatarPath;
  final int memberCount;
  final bool isMember;
  final DateTime createdAt;

  const NimzoFamily({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.ownerName,
    required this.ownerAvatarPath,
    required this.memberCount,
    required this.isMember,
    required this.createdAt,
  });

  factory NimzoFamily.fromRow(Map<String, dynamic> row) => NimzoFamily(
        id: row['id'].toString(),
        ownerId: row['owner_id'].toString(),
        name: row['name']?.toString() ?? 'Family',
        description: row['description']?.toString() ?? '',
        ownerName: row['owner_name']?.toString() ?? 'NIMZO Member',
        ownerAvatarPath: row['owner_avatar_path']?.toString(),
        memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
        isMember: row['is_member'] == true,
        createdAt: DateTime.parse(row['created_at'].toString()),
      );
}

class NimzoFamilyRepository {
  final SupabaseClient _db;
  NimzoFamilyRepository(this._db);

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in before using Family.');
    return id;
  }

  Future<List<NimzoFamily>> directory() async {
    // Aggregation is server-side: do not download all member records.
    final rows = await _db
        .from('nimzo_family_directory')
        .select(
          'id,owner_id,name,description,owner_name,owner_avatar_path,'
          'member_count,is_member,created_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => NimzoFamily.fromRow(row)).toList();
  }

  /// Generate once for a request and REUSE the same key when retrying
  /// after a timeout. The backend independently verifies idempotency.
  String newCreationKey() =>
      'family-${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32)}';

  Future<String> create({
    required String name,
    required String description,
    required String requestKey,
  }) async {
    _uid;
    final cleanedName = name.trim();
    if (cleanedName.length < 2 || cleanedName.length > 40) {
      throw const FormatException('Family name must be 2–40 characters.');
    }
    if (description.trim().length > 500) {
      throw const FormatException('Description cannot exceed 500 characters.');
    }
    // The server owns charging, validation and idempotency. Never mutate
    // wallets or ledger tables from the Flutter client.
    final response = await _db.rpc(
      'create_family',
      params: {
        'p_name': cleanedName,
        'p_description': description.trim(),
        'p_key': requestKey,
      },
    );
    if (response is! Map || response['created'] != true ||
        response['family_id'] == null) {
      throw StateError('Family creation was not confirmed by the server.');
    }
    return response['family_id'].toString();
  }

  Future<void> join(String familyId) async {
    final uid = _uid;
    await _db.from('nimzo_family_members').insert({
      'family_id': familyId,
      'user_id': uid,
    });
  }

  Future<void> leave(NimzoFamily family) async {
    final uid = _uid;
    if (family.ownerId == uid) {
      throw StateError('The family owner cannot leave their own Family.');
    }
    await _db
        .from('nimzo_family_members')
        .delete()
        .eq('family_id', family.id)
        .eq('user_id', uid);
  }
}

final nimzoFamilyRepositoryProvider = Provider<NimzoFamilyRepository>((ref) =>
    NimzoFamilyRepository(ref.watch(sessionSupabaseProvider).client));

final nimzoFamilyDirectoryProvider = FutureProvider.autoDispose<List<NimzoFamily>>(
  (ref) => ref.watch(nimzoFamilyRepositoryProvider).directory(),
);
