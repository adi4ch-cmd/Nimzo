import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile_repository.dart';
import 'social_repositories.dart';

final blockedUserIdsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(blockRepositoryProvider).blocked(),
);

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Blocked users')),
        body: AsyncContent(
          value: ref.watch(blockedUserIdsProvider),
          onRetry: () => ref.invalidate(blockedUserIdsProvider),
          builder: (ids) => ids.isEmpty
              ? const EmptyContent('No blocked users.')
              : ListView(
                  children: [for (final id in ids) _BlockedUser(id: id)]),
        ),
      );
}

class _BlockedUser extends ConsumerStatefulWidget {
  final String id;
  const _BlockedUser({required this.id});
  @override
  ConsumerState<_BlockedUser> createState() => _BlockedUserState();
}

class _BlockedUserState extends ConsumerState<_BlockedUser> {
  bool busy = false;
  Future<void> unblock() async {
    if (busy) return;
    setState(() => busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref.read(blockRepositoryProvider).unblock(widget.id);
      container.invalidate(blockedUserIdsProvider);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to unblock this user. Retry.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider(widget.id)).valueOrNull;
    return ListTile(
      title: Text(profile?.displayName ?? profile?.username ?? 'Blocked user'),
      subtitle: profile == null ? null : Text('ID:${profile.nimzoId}'),
      trailing: TextButton(
          onPressed: busy ? null : unblock,
          child: Text(busy ? 'Unblocking…' : 'Unblock')),
    );
  }
}
