import '../../vip/phoenix_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../gifts/gift_sheet.dart';
import '../../profile/profile_repository.dart';
import '../../profile/profile_screen.dart';
import '../../profile/levels_screen.dart';
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
    final roomOwner =
        ref.watch(roomProvider(widget.roomId)).valueOrNull?.ownerId;
    final owner = me != null && roomOwner == me;
    final canModerate = me != null &&
        (owner ||
            ref.watch(roomModerationProvider(widget.roomId)).valueOrNull ==
                true);
    final removable = canModerate && !self && widget.userId != roomOwner;
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
                            leading: PhoenixDecoration(
                                userId: widget.userId,
                                avatar: true,
                                child: NimzoAvatar(
                                    name: p.displayName ?? 'N',
                                    url: p.avatarPath == null
                                        ? null
                                        : ref
                                            .watch(supabaseProvider)
                                            .storage
                                            .from('avatars')
                                            .getPublicUrl(p.avatarPath!))),
                            title: PhoenixNameplate(
                                userId: widget.userId,
                                name: p.displayName ??
                                    p.username ??
                                    'Nimzo user'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID:${p.nimzoId}'),
                                const SizedBox(height: 6),
                                Row(
                                  key: const ValueKey('room-user-level-badges'),
                                  children: [
                                    for (var kind = 0; kind < 3; kind++) ...[
                                      if (kind > 0) const SizedBox(width: 4),
                                      Expanded(
                                          child: InkWell(
                                        key: ValueKey('room-user-level-$kind'),
                                        onTap: busy
                                            ? null
                                            : () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        LevelsScreen(
                                                            initialKind: kind,
                                                            userId: widget
                                                                .userId))),
                                        child: ProfileProgressBadge(
                                            kind: kind,
                                            level: [
                                              p.wealthLevel,
                                              p.charmLevel,
                                              p.activeLevel
                                            ][kind],
                                            total: [
                                              p.wealthCoins,
                                              p.charmDiamonds,
                                              p.activePoints
                                            ][kind]),
                                      )),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          )),
                  if (self)
                    ListTile(
                      title: const Text('Edit Profile'),
                      onTap: busy
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.pop(context);
                              router.push('/profile');
                            },
                    ),
                  ListTile(
                      title: Text(self ? 'My Profile' : 'View profile'),
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
                          FriendState.friends => 'Send Message',
                          FriendState.sent => 'Request sent',
                          FriendState.received => 'Accept friend request',
                          _ => 'Add friend',
                        }),
                        onTap: busy ||
                                friendship?.hasValue != true ||
                                friendship?.valueOrNull == FriendState.sent
                            ? null
                            : () => run(() async {
                                  if (friendship!.valueOrNull ==
                                      FriendState.friends) {
                                    final router = GoRouter.of(context);
                                    Navigator.pop(context);
                                    router.push('/chat/${widget.userId}');
                                    return;
                                  }
                                  final repo =
                                      ref.read(friendRepositoryProvider);
                                  if (friendship.valueOrNull ==
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
                                  if (context.mounted) Navigator.pop(context);
                                })),
                  if (removable)
                    ListTile(
                        title: Text(widget.muted ? 'Unmute seat' : 'Mute seat'),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  await ref
                                      .read(roomRepositoryProvider)
                                      .modMuteSeat(widget.roomId, widget.seatNo,
                                          !widget.muted);
                                  if (context.mounted) Navigator.pop(context);
                                })),
                  if (removable)
                    for (final ban in [false, true])
                      ListTile(
                        title: Text(ban ? 'Ban from room' : 'Kick from room'),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: Text(ban
                                          ? 'Permanently ban this user from the room?'
                                          : 'Remove this user from the room?'),
                                      content: Text(ban
                                          ? 'This user will not be able to rejoin this room.'
                                          : 'This user can rejoin the room.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child:
                                                Text(ban ? 'Ban' : 'Remove')),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true || !context.mounted)
                                    return;
                                  await ref
                                      .read(roomRepositoryProvider)
                                      .moderateMember(
                                          widget.roomId, widget.userId,
                                          ban: ban);
                                  if (context.mounted) Navigator.pop(context);
                                }),
                      ),
                ]))));
  }
}
