import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../gifts/gift_sheet.dart';
import '../../profile/profile_repository.dart';
import '../../social/social_repositories.dart';
import 'room_controller.dart';
import '../../voice/voice_controller.dart';

class RoomUserSheet extends ConsumerStatefulWidget {
  final String roomId, userId;
  final int seatNo;
  final bool muted;
  const RoomUserSheet(
      {super.key,
      required this.roomId,
      required this.userId,
      required this.seatNo,
      required this.muted});
  @override
  ConsumerState<RoomUserSheet> createState() => _RoomUserSheetState();
}

class _RoomUserSheetState extends ConsumerState<RoomUserSheet> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Action could not be completed. Please retry.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final self = widget.userId == me;
    final owner =
        ref.watch(roomProvider(widget.roomId)).valueOrNull?.ownerId == me &&
            me != null;
    final following =
        self ? null : ref.watch(isFollowingProvider(widget.userId));
    final friendship =
        self ? null : ref.watch(friendStateProvider(widget.userId));
    return SafeArea(
        child: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AsyncContent(
                      value: ref.watch(profileProvider(widget.userId)),
                      onRetry: () =>
                          ref.invalidate(profileProvider(widget.userId)),
                      builder: (p) => ListTile(
                            leading: NimzoAvatar(
                                name: p.displayName ?? 'N',
                                url: p.avatarPath == null
                                    ? null
                                    : ref
                                        .watch(supabaseProvider)
                                        .storage
                                        .from('avatars')
                                        .getPublicUrl(p.avatarPath!)),
                            title: Text(
                                p.displayName ?? p.username ?? 'Nimzo user'),
                            subtitle: Text('ID:${p.nimzoId}'),
                          )),
                  ListTile(
                      title: const Text('View profile'),
                      onTap: busy
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.pop(context);
                              router.push('/profile/${widget.userId}');
                            }),
                  if (!self)
                    ListTile(
                        title: Text(following?.valueOrNull == true
                            ? 'Unfollow'
                            : 'Follow'),
                        subtitle: following?.hasError == true
                            ? const Text('Status unavailable. Tap to retry.')
                            : null,
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  if (following?.hasValue != true) {
                                    ref.invalidate(
                                        isFollowingProvider(widget.userId));
                                    return;
                                  }
                                  final repo =
                                      ref.read(followRepositoryProvider);
                                  if (following!.valueOrNull == true) {
                                    await repo.unfollow(widget.userId);
                                  } else {
                                    await repo.follow(widget.userId);
                                  }
                                  if (mounted)
                                    ref.invalidate(
                                        isFollowingProvider(widget.userId));
                                })),
                  if (!self)
                    ListTile(
                        title: Text(switch (friendship?.valueOrNull) {
                          FriendState.friends => 'Friends',
                          FriendState.sent => 'Request sent',
                          FriendState.received => 'Accept friend request',
                          _ => 'Add friend',
                        }),
                        onTap: busy ||
                                friendship?.hasValue != true ||
                                friendship?.valueOrNull ==
                                    FriendState.friends ||
                                friendship?.valueOrNull == FriendState.sent
                            ? null
                            : () => run(() async {
                                  final repo =
                                      ref.read(friendRepositoryProvider);
                                  if (friendship!.valueOrNull ==
                                      FriendState.received) {
                                    await repo.accept(widget.userId);
                                  } else {
                                    await repo.request(widget.userId);
                                  }
                                  if (mounted)
                                    ref.invalidate(
                                        friendStateProvider(widget.userId));
                                })),
                  ListTile(
                      title: const Text('Send gift'),
                      onTap: busy || me == null
                          ? null
                          : () {
                              final parent = Navigator.of(context);
                              final outer = parent.context;
                              Navigator.pop(context);
                              showRoomGiftSheet(
                                  outer, widget.roomId, widget.userId);
                            }),
                  if (self)
                    ListTile(
                        title: const Text('Leave seat'),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  final repository =
                                      ref.read(roomRepositoryProvider);
                                  final voice = ref.read(voiceServiceProvider);
                                  await repository.leaveSeat(widget.roomId);
                                  try {
                                    await voice.setMicEnabled(false);
                                  } catch (_) {
                                    await voice.leave();
                                  }
                                  if (mounted) Navigator.pop(context);
                                })),
                  if (owner && !self)
                    ListTile(
                        title: Text(widget.muted ? 'Unmute seat' : 'Mute seat'),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  await ref
                                      .read(roomRepositoryProvider)
                                      .modMuteSeat(widget.roomId, widget.seatNo,
                                          !widget.muted);
                                  if (mounted) Navigator.pop(context);
                                })),
                  if (owner && !self)
                    ListTile(
                        title: const Text('Kick from room'),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                              title: const Text(
                                                  'Remove this user from the room?'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c, false),
                                                    child:
                                                        const Text('Cancel')),
                                                FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c, true),
                                                    child:
                                                        const Text('Remove')),
                                              ]));
                                  if (confirmed != true || !mounted) return;
                                  await ref
                                      .read(roomRepositoryProvider)
                                      .kick(widget.roomId, widget.userId);
                                  if (mounted) Navigator.pop(context);
                                })),
                ]))));
  }
}
