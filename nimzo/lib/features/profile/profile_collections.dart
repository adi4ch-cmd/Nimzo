import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

enum ProfileCollection { medal, frame, car }

final profileCollectionProvider = FutureProvider.family<
    List<Map<String, dynamic>>, (String, ProfileCollection)>((ref, args) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('profile_owned_collectibles')
      .select('expires_at,profile_collectibles!inner(*)')
      .eq('user_id', args.$1)
      .eq('profile_collectibles.kind', args.$2.name);
  final now = DateTime.now();
  return rows
      .where(
        (r) =>
            r['expires_at'] == null ||
            DateTime.parse(r['expires_at']).isAfter(now),
      )
      .map((r) => Map<String, dynamic>.from(r['profile_collectibles']))
      .toList();
});
