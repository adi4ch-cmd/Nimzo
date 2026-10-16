import '../../vip/phoenix_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../gifts/gift_sheet.dart';
import '../../profile/levels_screen.dart';
import '../../profile/profile_level_pills.dart';
import '../../profile/profile_membership_status.dart';
import '../../profile/profile_repository.dart';
import '../../social/social_repositories.dart';
import '../../store/store_badge.dart';
import '../../voice/voice_controller.dart';
import 'room_controller.dart';

/// Compact in-room profile card. Its badges and social state are read from the
/// same authoritative providers as the public profile; the screenshot is
/// a layout reference, not a source of invented achievements or levels.
class RoomUserSheet extends ConsumerStatefulWidget {
  final String roomId, userId;
  final int seatNo;
  final bool muted;
  final ValueChanged<String>? onMention;

  const RoomUserSheet({
    super.key,
    required this.roomId,
    required this.userId,
    required this.seatNo,
    required this.muted,
    this.onMention,
  });

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action could not be completed. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openProfile() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/profile/${widget.userId}');
  }

  void gift() {
    final navigator = Navigator.of(context);
    final outer = navigator.context;
    navigator.pop();
    showRoomGiftSheet(outer, widget.roomId, widget.userId);
  }

  Future<void> changeFollow(AsyncValue<bool>? following) => run(() async {
        if (following?.hasValue != true) {
          ref.invalidate(isFollowingProvider(widget.userId));
          return;
        }
        final repo = ref.read(followRepositoryProvider);
        if (following!.valueOrNull == true) {
          await repo.unfollow(widget.userId);
        } else {
          await repo.follow(widget.userId);
        }
        ref.invalidate(isFollowingProvider(widget.userId));
      });

  Future<void> changeFriend(AsyncValue<FriendState>? friendship) =>
      run(() async {
        if (friendship?.hasValue != true) {
          ref.invalidate(friendStateProvider(widget.userId));
          return;
        }
        if (friendship!.valueOrNull == FriendState.friends) {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push('/chat/${widget.userId}');
          return;
        }
        final repo = ref.read(friendRepositoryProvider);
        if (friendship.valueOrNull == FriendState.received) {
          await repo.accept(widget.userId);
        } else if (friendship.valueOrNull == FriendState.none) {
          await repo.request(widget.userId);
        }
        ref.invalidate(friendStateProvider(widget.userId));
      });

  Future<void> moderate({required bool ban}) => run(() async {
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
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(ban ? 'Ban' : 'Remove'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await ref.read(roomRepositoryProvider).moderateMember(
              widget.roomId,
              widget.userId,
              ban: ban,
            );
        if (mounted) Navigator.of(context).pop();
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final self = widget.userId == me;
    final roomOwner =
        ref.watch(roomProvider(widget.roomId)).valueOrNull?.ownerId;
    final canModerate = me != null &&
        (roomOwner == me ||
            ref.watch(roomModerationProvider(widget.roomId)).valueOrNull ==
                true);
    final removable = canModerate && !self && widget.userId != roomOwner;
    final following =
        self ? null : ref.watch(isFollowingProvider(widget.userId));
    final friendship =
        self ? null : ref.watch(friendStateProvider(widget.userId));

    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Container(
              key: const ValueKey('room-mini-profile-card'),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              decoration: BoxDecoration(
                color: const Color(0xff302e31),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xff484348)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x50000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AsyncContent(
                    value: ref.watch(profileProvider(widget.userId)),
                    onRetry: () =>
                        ref.invalidate(profileProvider(widget.userId)),
                    builder: (p) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: openProfile,
                              child: PhoenixDecoration(
                                userId: widget.userId,
                                avatar: true,
                                child: NimzoAvatar(
                                  name: p.displayName ?? 'N',
                                  size: 66,
                                  url: p.avatarPath == null
                                      ? null
                                      : ref
                                          .read(supabaseProvider)
                                          .storage
                                          .from('avatars')
                                          .getPublicUrl(p.avatarPath!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: openProfile,
                                    child: PhoenixNameplate(
                                      userId: widget.userId,
                                      name: p.displayName ??
                                          p.username ??
                                          'Nimzo user',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        'ID:${p.nimzoId}',
                                        style: const TextStyle(
                                          color: Color(0xffceccd1),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: EquippedRoyalMedal(
                                          userId: widget.userId,
                                          compact: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    key: const ValueKey(
                                        'room-user-level-badges'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var kind = 0;
                                          kind < 3;
                                          kind++) ...[
                                        if (kind > 0)
                                          const SizedBox(width: 4),
                                        Flexible(
                                          child: InkWell(
                                            key: ValueKey(
                                                'room-user-level-$kind'),
                                            onTap: busy
                                                ? null
                                                : () =>
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            LevelsScreen(
                                                          initialKind: kind,
                                                          userId:
                                                              widget.userId,
                                                        ),
                                                      ),
                                                    ),
                                            child: ProfileLevelPill(
                                              kind: kind,
                                              level: [
                                                p.wealthLevel,
                                                p.charmLevel,
                                                p.activeLevel,
                                              ][kind],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ProfileMembershipStatus(
                          profile: p,
                          editable: self,
                          compact: true,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            if (!self) ...[
                              Expanded(
                                child: _MiniAction(
                                  icon: Icons.favorite_border,
                                  color: const Color(0xfffa70ab),
                                  label: following?.valueOrNull == true
                                      ? 'Unfollow'
                                      : 'Follow',
                                  onTap: busy
                                      ? null
                                      : () => changeFollow(following),
                                ),
                              ),
                              Expanded(
                                child: _MiniAction(
                                  icon: Icons.person_add_alt_1,
                                  color: const Color(0xff4bd9c7),
                                  label: switch (friendship?.valueOrNull) {
                                    FriendState.friends => 'Message',
                                    FriendState.sent => 'Request sent',
                                    FriendState.received => 'Accept friend',
                                    _ => 'Add friend',
                                  },
                                  onTap: busy ||
                                          friendship?.hasValue != true ||
                                          friendship?.valueOrNull ==
                                              FriendState.sent
                                      ? null
                                      : () => changeFriend(friendship),
                                ),
                              ),
                              Expanded(
                                child: _MiniAction(
                                  icon: Icons.alternate_email,
                                  color: const Color(0xffff9754),
                                  label: 'Mention',
                                  onTap: busy || widget.onMention == null
                                      ? null
                                      : () {
                                          widget.onMention!.call(
                                            p.displayName ??
                                                p.username ??
                                                p.nimzoId.toString(),
                                          );
                                          Navigator.of(context).pop();
                                        },
                                ),
                              ),
                            ],
                            Expanded(
                              child: _MiniAction(
                                icon: Icons.card_giftcard,
                                color: const Color(0xffdfd94a),
                                label: 'Send Gifts',
                                onTap: busy || me == null ? null : gift,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Working…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffd8d3db), fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (self)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  final router = GoRouter.of(context);
                                  Navigator.pop(context);
                                  router.push('/profile');
                                },
                          child: const Text('Edit Profile'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                    final repository =
                                        ref.read(roomRepositoryProvider);
                                    final voice =
                                        ref.read(voiceServiceProvider);
                                    await repository.leaveSeat(widget.roomId);
                                    try {
                                      await voice.setMicEnabled(false);
                                    } catch (_) {
                                      await voice.leave();
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                  }),
                          child: const Text('Leave seat'),
                        ),
                      ],
                    ),
                  if (removable) ...[
                    const Divider(color: Color(0xff4d494d)),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                    await ref
                                        .read(roomRepositoryProvider)
                                        .modMuteSeat(
                                          widget.roomId,
                                          widget.seatNo,
                                          !widget.muted,
                                        );
                                    if (context.mounted) Navigator.pop(context);
                                  }),
                          child: Text(widget.muted
                              ? 'Unmute seat'
                              : 'Mute seat'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => moderate(ban: false),
                          child: const Text('Kick from room'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => moderate(ban: true),
                          child: const Text(
                            'Ban from room',
                            style: TextStyle(color: Color(0xffff7777)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: onTap == null ? .46 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 27, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
