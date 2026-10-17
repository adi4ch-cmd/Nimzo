import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';

final blockedPeopleProvider = FutureProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(sessionSupabaseProvider).client;
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return [];
  final blocks = await db.from('blocks')
      .select('blocked_id').eq('blocker_id', me).limit(150);
  final ids = blocks.map((x) => x['blocked_id'].toString()).toList();
  if (ids.isEmpty) return [];
  final profiles = await db.from('profiles')
      .select('id,nimzo_id,display_name,avatar_path')
      .inFilter('id', ids);
  final indexed = <String, Map<String, dynamic>>{
    for (final p in profiles) p['id'].toString(): Map<String,dynamic>.from(p)
  };
  return [
    for (final id in ids) <String, dynamic>{
      'id': id,
      ...?indexed[id],
    }
  ];
});

class TingleBlockedUsersScreen extends ConsumerStatefulWidget {
  const TingleBlockedUsersScreen({super.key});

  @override
  ConsumerState<TingleBlockedUsersScreen> createState() => _State();
}

class _State extends ConsumerState<TingleBlockedUsersScreen> {
  String? working;

  Future<void> unblock(String id) async {
    if (working != null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Unblock this user?'),
        content: const Text('This account will be able to interact with you again according to your privacy settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => working = id);
    try {
      final db = ref.read(sessionSupabaseProvider).client;
      final me = ref.read(currentUserIdProvider);
      if (me == null) throw StateError('Sign in required');
      await db.from('blocks').delete().eq('blocker_id', me)
          .eq('blocked_id', id);
      ref.invalidate(blockedPeopleProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to unblock. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(blockedPeopleProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(blockedPeopleProvider);
          await ref.read(blockedPeopleProvider.future);
        },
        child: people.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            const SizedBox(height: 80),
            const Center(child: Text('Could not load blocked accounts')),
            TextButton(
              onPressed: () => ref.invalidate(blockedPeopleProvider),
              child: const Text('Retry'),
            ),
          ]),
          data: (items) => items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 100),
                Center(child: Icon(Icons.person_off_outlined,
                  size: 50, color: Color(0xffb9afd4))),
                SizedBox(height: 16),
                Center(child: Text('No blocked users')),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(22),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 22),
                itemBuilder: (context, index) {
                  final p = items[index];
                  final id = p['id'].toString();
                  final avatarPath = p['avatar_path'] as String?;
                  final url = avatarPath == null ? null
                    : ref.watch(sessionSupabaseProvider).client.storage
                        .from('avatars').getPublicUrl(avatarPath);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xffefe5fc),
                      backgroundImage: url == null ? null : NetworkImage(url),
                      child: url == null
                        ? const Icon(Icons.person, color: NimzoStyle.primary)
                        : null,
                    ),
                    title: Text((p['display_name'] as String?) ?? 'NIMZO user',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('ID: ' + (p['nimzo_id']?.toString() ?? id)),
                    trailing: OutlinedButton(
                      onPressed: working != null ? null : () => unblock(id),
                      child: Text(working == id ? 'Wait…' : 'Unblock'),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}
