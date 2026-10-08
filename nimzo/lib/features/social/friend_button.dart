import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'social_repositories.dart';

/// Uses the existing friend request/accept contracts; state changes only on success.
class ReferenceFriendButton extends ConsumerStatefulWidget {
  final String userId;
  const ReferenceFriendButton({super.key, required this.userId});
  @override
  ConsumerState<ReferenceFriendButton> createState() => _FriendState();
}

class _FriendState extends ConsumerState<ReferenceFriendButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendStateProvider(widget.userId));
    final value = state.valueOrNull;
    return FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: const Color(0xffdbeafe),
          foregroundColor: const Color(0xff2563eb)),
      onPressed: busy ||
              !state.hasValue ||
              value == FriendState.sent ||
              value == FriendState.friends
          ? null
          : () async {
              setState(() => busy = true);
              final container =
                  ProviderScope.containerOf(context, listen: false);
              final recipient = widget.userId;
              try {
                final repo = ref.read(friendRepositoryProvider);
                value == FriendState.received
                    ? await repo.accept(recipient)
                    : await repo.request(recipient);
                container.invalidate(friendStateProvider(recipient));
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Friend request could not be completed. Retry.')));
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
      child: Text(
          busy
              ? 'Sending…'
              : switch (value) {
                  FriendState.sent => 'Requested',
                  FriendState.received => 'Accept',
                  FriendState.friends => 'Friends',
                  _ => 'Add Friend'
                },
          maxLines: 1,
          style: const TextStyle(fontSize: 12, color: NimzoStyle.primary)),
    );
  }
}
