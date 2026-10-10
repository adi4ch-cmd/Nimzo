import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

class RoyalStoreItem {
  final String id;
  final String name;
  final String image;
  final String description;
  final int price;
  const RoyalStoreItem({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.price,
  });

  factory RoyalStoreItem.fromJson(Map<String, dynamic> row) {
    final item = Map<String, dynamic>.from(row['profile_collectibles'] as Map);
    return RoyalStoreItem(
      id: item['id'] as String,
      name: item['name'] as String,
      image: item['image_path'] as String,
      description: item['description']?.toString() ?? '',
      price: (row['coin_price'] as num).toInt(),
    );
  }
}

class RoyalBagItem {
  final String id;
  final String name;
  final String image;
  final bool equipped;
  final DateTime? expiry;
  const RoyalBagItem({
    required this.id,
    required this.name,
    required this.image,
    required this.equipped,
    this.expiry,
  });

  factory RoyalBagItem.fromJson(Map<String, dynamic> row) {
    final item = Map<String, dynamic>.from(row['profile_collectibles'] as Map);
    return RoyalBagItem(
      id: item['id'] as String,
      name: item['name'] as String,
      image: item['image_path'] as String,
      equipped: row['equipped'] == true,
      expiry: row['expires_at'] == null
          ? null
          : DateTime.parse(row['expires_at'] as String),
    );
  }
}

class RoyalStoreRepository {
  final SupabaseClient db;
  RoyalStoreRepository(this.db);

  Future<List<RoyalStoreItem>> catalog() async {
    final rows = await db
        .from('nimzo_store_catalog')
        .select(
          'coin_price,profile_collectibles!inner(id,name,image_path,description)',
        )
        .eq('active', true)
        .order('coin_price');
    return rows.map((r) => RoyalStoreItem.fromJson(r)).toList();
  }

  Future<List<RoyalBagItem>> bag(String userId) async {
    final rows = await db
        .from('profile_owned_collectibles')
        .select(
          'equipped,expires_at,profile_collectibles!inner(id,name,image_path,kind)',
        )
        .eq('user_id', userId)
        .eq('profile_collectibles.kind', 'medal');
    final now = DateTime.now();
    return rows
        .map((r) => RoyalBagItem.fromJson(r))
        .where((item) => item.expiry == null || item.expiry!.isAfter(now))
        .toList();
  }

  // Retry the SAME key after an uncertain response to prevent double charging.
  Future<void> buy(String itemId, String requestKey) async {
    final result = await db.rpc(
      'nimzo_store_buy',
      params: {'p_collectible': itemId, 'p_request_key': requestKey},
    );
    if (result is! Map || result['purchased'] != true) {
      throw StateError('Purchase could not be verified');
    }
  }

  Future<void> equip(String itemId) async {
    final result = await db.rpc(
      'nimzo_store_equip',
      params: {'p_collectible': itemId},
    );
    if (result != true) throw StateError('Medal selection not confirmed');
  }

  String newPurchaseKey() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
}

final royalStoreRepositoryProvider = Provider(
  (ref) => RoyalStoreRepository(ref.watch(sessionSupabaseProvider).client),
);
final royalCatalogProvider = FutureProvider(
  (ref) => ref.watch(royalStoreRepositoryProvider).catalog(),
);
final royalBagProvider = FutureProvider.family<List<RoyalBagItem>, String>(
  (ref, id) => ref.watch(royalStoreRepositoryProvider).bag(id),
);
