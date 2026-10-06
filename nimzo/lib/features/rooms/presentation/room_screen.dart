import 'dart:async';

import '../../voice/voice_service.dart';
import '../../../core/widgets/nimzo_icon.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../gifts/gift_animation_service.dart';
import '../../gifts/gift_sheet.dart';
import '../../voice/voice_controller.dart';
import '../data/room_chat_repository.dart';
import '../data/room_settings_repository.dart';
import '../domain/room.dart';
import '../../profile/profile.dart';
import '../../social/social_repositories.dart';
import '../../../core/widgets/nimzo_avatar.dart';
import '../../../core/utils/helpers.dart';
import '../domain/room_theme.dart';
import 'room_controller.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});
  @override
  ConsumerState<RoomScreen> createState() => _S();
}

class _S extends ConsumerState<RoomScreen> {
  late final RoomActions _actions;
  late final VoiceService _voice;
  late final RoomChatRepository _chatRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _membership;
  bool _voiceReady = false, _voiceJoining = false, _micUpdating = false;
  String? _voiceError;
  String? _memberRole;
  RealtimeChannel? _roomChanges;
  bool _giftFeedInitialized = false;
  String? _lastGiftEventId;
  final _chat = TextEditingController();
  String? _receiver;
  bool _micOn = false, _joined = false;

  @override
  void initState() {
    super.initState();
    _actions = ref.read(roomActionsProvider);
    _voice = ref.read(voiceServiceProvider);
    _chatRepository = ref.read(roomChatRepositoryProvider);
    Future.microtask(_enter);
  }

  Future<void> _enter({String? password}) async {
    try {
      await _actions.enter(widget.roomId, password: password);
      if (!mounted) {
        await _actions.exit(widget.roomId);
        return;
      }
      setState(() {
        _joined = true;
        _voiceJoining = true;
      });
      final db = ref.read(supabaseProvider);
      final uid = db.auth.currentUser?.id;
      _roomChanges = db
          .channel('room-voice-${widget.roomId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.roomId,
            ),
            callback: (_) {
              if (mounted) ref.invalidate(roomProvider(widget.roomId));
            },
          )
          .subscribe();
      _membership = db
          .from('room_members')
          .stream(primaryKey: ['room_id', 'user_id'])
          .eq('room_id', widget.roomId)
          .listen(
            (rows) {
              final mine = rows.where((row) => row['user_id'] == uid).toList();
              if (!mounted) return;
              if (mine.isEmpty) {
                unawaited(_voice.leave().catchError((_) {}));
                setState(() {
                  _micOn = false;
                  _voiceReady = false;
                });
                _snack('Your room session ended.');
                if (context.canPop()) context.pop();
              } else {
                setState(() => _memberRole = mine.first['role']?.toString());
                if (_micOn && !_maySpeak(ref.read(seatsProvider(widget.roomId)).valueOrNull ?? [], ref.read(roomProvider(widget.roomId)).valueOrNull, uid)) unawaited(_mute());
              }
            },
            onError: (Object e) {
              if (mounted) _snack('Room connection unavailable: $e');
              unawaited(_voice.leave().catchError((_) {}));
              if (mounted)
                setState(() {
                  _micOn = false;
                  _voiceReady = false;
                });
            },
          );
      await _joinVoice();
    } catch (e) {
      if (!mounted) return;
      if ('$e'.contains('password')) {
        final pw = await _askPassword();
        if (pw != null) return _enter(password: pw);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      if (context.canPop()) context.pop();
    }
  }

  Future<void> _joinVoice() async {
    if (!mounted) return;
    setState(() {
      _voiceJoining = true;
      _voiceError = null;
    });
    try {
      await _voice.join(widget.roomId, '');
      if (!mounted) {
        await _voice.leave();
        return;
      }
      setState(() {
        _voiceReady = true;
        _voiceError = null;
        _voiceJoining = false;
        _micOn = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _voiceReady = false;
          _voiceJoining = false;
          _voiceError = '$e';
        });
    }
  }

  bool _maySpeak(List<MicSeat> seats, Room? room, String? uid) {
    if (uid == null || room == null || room.status != 'open') return false;
    final occupied = seats.any((s) => s.userId == uid && !s.muted && !s.locked);
    final allowed =
        room.permissions['mic_permission'] != 'mods' ||
        room.ownerId == uid ||
        _memberRole == 'moderator';
    final micSwitchAllowed = room.micEnabled || room.ownerId == uid || _memberRole == 'moderator';
    return occupied && allowed && micSwitchAllowed;
  }

  Future<void> _mute() async {
    if (!_voiceReady && !_micOn) return;
    try {
      await _voice.setMicEnabled(false);
    } catch (e) {
      // If the transport cannot confirm mute, disconnect instead.
      await _voice.leave().catchError((_) {});
      if (mounted) _snack('$e');
    }
    if (mounted) setState(() => _micOn = false);
  }

  Future<String?> _askPassword() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Room password'),
        content: TextField(controller: c, obscureText: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chat.dispose();
    unawaited(_membership?.cancel());
    unawaited(_roomChanges?.unsubscribe());
    unawaited(_voice.leave().catchError((_) {}));
    if (_joined) {
      // Room chat is ephemeral: clear it when the current room session ends.
      _chatRepository.clear(widget.roomId).catchError((_) {});
      unawaited(_actions.exit(widget.roomId).catchError((_) {}));
    }
    super.dispose();
  }

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.roomId));
    final seats = ref.watch(seatsProvider(widget.roomId));
    final speaking = ref.watch(speakingProvider).valueOrNull ?? {};
    final online =
        ref.watch(onlineCountProvider(widget.roomId)).valueOrNull ?? 0;
    final me = ref.watch(currentUserIdProvider);
    ref.listen(voiceConnectedProvider, (_, next) {
      if (next.valueOrNull == true && mounted) {
        setState(() { _voiceReady = true; _voiceError = null; });
      }
      if (next.valueOrNull == false && _voiceReady && mounted) {
        setState(() {
          _voiceReady = false;
          _micOn = false;
          _voiceError = _micUpdating || _voiceJoining ? null : 'Audio disconnected';
        });
      }
    });
    ref.listen(seatsProvider(widget.roomId), (_, next) {
      if (_micOn &&
          !_maySpeak(
            next.valueOrNull ?? [],
            ref.read(roomProvider(widget.roomId)).valueOrNull,
            me,
          ))
        unawaited(_mute());
    });
    ref.listen(roomProvider(widget.roomId), (_, next) {
      if (next.valueOrNull?.status != null && next.valueOrNull!.status != 'open') {
        unawaited(_voice.leave().catchError((_) {}));
      }
      if (_micOn &&
          !_maySpeak(
            ref.read(seatsProvider(widget.roomId)).valueOrNull ?? [],
            next.valueOrNull,
            me,
          ))
        unawaited(_mute());
    });

    ref.listen(roomGiftEventProvider(widget.roomId), (_, n) {
      final l = n.valueOrNull;
      if (l == null) return;
      final id = l.isEmpty ? null : l.first['id']?.toString();
      if (!_giftFeedInitialized) {
        _giftFeedInitialized = true;
        _lastGiftEventId = id;
        return;
      }
      if (id == null || id == _lastGiftEventId) return;
      _lastGiftEventId = id;
      if (l.isNotEmpty)
        GiftAnimationService.play(
          context,
          'Gift x${l.first['quantity']}',
          giftId: l.first['gift_id']?.toString(),
          quantity: (l.first['quantity'] as num?)?.toInt() ?? 1,
        );
    });

    final r = room.valueOrNull;
    final theme = RoomTheme.byId(r?.theme ?? 'nimzo_white');
    final isOwner = r != null && r.ownerId == me;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.gradient.first),
        child: SafeArea(
          child: room.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(roomProvider(widget.roomId)),
            ),
            data: (rm) => DefaultTextStyle.merge(
              style: TextStyle(color: theme.text),
              child: IconTheme(
                data: IconThemeData(color: theme.text),
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final owner = ref
                            .watch(roomOwnerProfileProvider(rm.id))
                            .valueOrNull;
                        final db = ref.watch(supabaseProvider);
                        final roomAvatar =
                            storageUrl(db, 'avatars', rm.avatarPath) ??
                            storageUrl(db, 'avatars', owner?.avatarPath);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .86),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => context.pop(),
                              ),
                              NimzoAvatar(
                                radius: 24,
                                url: roomAvatar,
                                online: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rm.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'ID ${rm.roomNo}  ·  $online online',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Lifetime Gifting: ${rm.lifetimeGiftCoins} coins',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: 'nimzo://room/${rm.id}',
                                    ),
                                  );
                                  _snack('Room link copied');
                                },
                              ),
                              IconButton(
                                icon: const NimzoIcon(Icons.settings_outlined),
                                onPressed: () => context.push(
                                  '/room/${rm.id}/settings?owner=$isOwner',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    seats.when(
                      loading: () =>
                          const SizedBox(height: 180, child: LoadingView()),
                      error: (e, _) => SizedBox(
                        height: 180,
                        child: ErrorView(
                          message: '$e',
                          onRetry: () =>
                              ref.invalidate(seatsProvider(widget.roomId)),
                        ),
                      ),
                      data: (list) {
                        final byNo = {for (final s in list) s.seatNo: s};
                        final profiles =
                            ref
                                .watch(roomSeatProfilesProvider(widget.roomId))
                                .valueOrNull ??
                            const <String, Profile>{};
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 5,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 6,
                          childAspectRatio: .78,
                          children: [
                            for (var i = 1; i <= 10; i++)
                              _Seat(
                                seat: byNo[i] ?? MicSeat(seatNo: i),
                                profile: byNo[i]?.userId == null
                                    ? null
                                    : profiles[byNo[i]!.userId],
                                speaking: speaking,
                                selected:
                                    byNo[i]?.userId == _receiver &&
                                    _receiver != null,
                                onTap: () {
                                  final s = byNo[i] ?? MicSeat(seatNo: i);
                                  if (s.userId == null) {
                                    if (!s.locked)
                                      _actions
                                          .seat(widget.roomId, i)
                                          .catchError((e) => _snack('$e'));
                                  } else {
                                    setState(() => _receiver = s.userId);
                                    final profile = profiles[s.userId];
                                    if (profile != null)
                                      _openUserSheet(
                                        context,
                                        rm,
                                        s,
                                        profile,
                                        isOwner,
                                      );
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    if (_voiceJoining)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Connecting room audio…'),
                      ),
                    if (_voiceError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Room audio unavailable',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: _voiceJoining ? null : _joinVoice,
                              child: const Text('Retry audio'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    _RoomGiftFeed(roomId: widget.roomId),
                    Expanded(child: _ChatList(roomId: widget.roomId)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chat,
                              style: TextStyle(color: theme.text),
                              decoration: const InputDecoration(
                                hintText: 'Say something',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const NimzoIcon(Icons.send),
                            onPressed: () async {
                              final t = _chat.text.trim();
                              if (t.isEmpty) return;
                              _chat.clear();
                              try {
                                await ref
                                    .read(roomChatRepositoryProvider)
                                    .send(widget.roomId, t);
                              } catch (e) {
                                _snack('$e');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          tooltip: 'Gift',
                          icon: const NimzoIcon(Icons.card_giftcard),
                          onPressed: () {
                            if (_receiver == null)
                              return _snack(
                                'Tap a seat to choose who receives the gift',
                              );
                            showGiftSheet(context, widget.roomId, _receiver!);
                          },
                        ),
                        IconButton(
                          tooltip: 'Mic',
                          icon: NimzoIcon(_micOn ? Icons.mic : Icons.mic_off),
                          onPressed: !_voiceReady || _micUpdating
                              ? null
                              : () async {
                                  if (!_micOn &&
                                      !_maySpeak(
                                        seats.valueOrNull ?? [],
                                        r,
                                        me,
                                      ))
                                    return _snack(
                                      'Take an available, unmuted seat to speak.',
                                    );
                                  final enabled = !_micOn;
                                  setState(() => _micUpdating = true);
                                  try {
                                    await _voice.setMicEnabled(enabled);
                                    if (!mounted) return;
                                    final stillAllowed = _maySpeak(ref.read(seatsProvider(widget.roomId)).valueOrNull ?? [], ref.read(roomProvider(widget.roomId)).valueOrNull, me);
                                      if (enabled && !stillAllowed) { await _mute(); }
                                      else { setState(() => _micOn = enabled); }
                                  } catch (e) {
                                    if (mounted) _snack('$e');
                                  } finally {
                                    if (mounted) setState(() => _micUpdating = false);
                                  }
                                },
                        ),
                        IconButton(
                          tooltip: 'Leave seat',
                          icon: const NimzoIcon(Icons.event_seat_outlined),
                          onPressed: () async {
                            await _mute();
                            try {
                              await _actions.unseat(widget.roomId);
                            } catch (e) {
                              if (mounted) _snack('$e');
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Game',
                          icon: const NimzoIcon(Icons.sports_esports_outlined),
                          onPressed: () =>
                              context.push('/games-play?room=${rm.id}'),
                        ),

                        IconButton(
                          tooltip: 'More',
                          icon: const NimzoIcon(Icons.more_horiz),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            builder: (_) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.favorite_border),
                                    title: const Text('Follow room'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      try {
                                        await ref
                                            .read(roomRepositoryProvider)
                                            .followRoom(rm.id, true);
                                        _snack('Room followed');
                                      } catch (e) {
                                        _snack('$e');
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.flag_outlined),
                                    title: const Text('Report room'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      try {
                                        await ref
                                            .read(
                                              roomSettingsRepositoryProvider,
                                            )
                                            .report(rm.id, 'user_report');
                                        _snack('Report sent');
                                      } catch (e) {
                                        _snack('$e');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  final String roomId;
  const _ChatList({required this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(roomChatProvider(roomId))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(
          child: Text(
            'Chat unavailable',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        data: (l) => ListView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            for (final m in l)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(m.body),
              ),
          ],
        ),
      );
}

class _Seat extends StatelessWidget {
  final MicSeat seat;
  final Profile? profile;
  final Set<String> speaking;
  final bool selected;
  final VoidCallback onTap;
  const _Seat({
    required this.seat,
    required this.profile,
    required this.speaking,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = seat.userId != null && speaking.contains(seat.userId);
    final db = Supabase.instance.client;
    final avatar = storageUrl(db, 'avatars', profile?.avatarPath);
    final name = profile?.displayName?.trim().isNotEmpty == true
        ? profile!.displayName!
        : (profile?.nimzoId.toString() ?? 'User');
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active || selected
                    ? const Color(0xFF22C55E)
                    : const Color(0x40808080),
                width: active
                    ? 3
                    : selected
                    ? 2
                    : 1,
              ),
            ),
            child: NimzoAvatar(
              radius: 22,
              url: avatar,
              online: seat.userId != null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            seat.userId == null ? '${seat.seatNo}' : name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (seat.muted)
            const NimzoIcon(Icons.mic_off, size: 12, color: Color(0xFFEF4444)),
        ],
      ),
    );
  }
}

Future<void> _openUserSheet(
  BuildContext context,
  Room room,
  MicSeat seat,
  Profile profile,
  bool isOwner,
) async {
  final db = Supabase.instance.client;
  final avatar = storageUrl(db, 'avatars', profile.avatarPath);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                NimzoAvatar(radius: 30, url: avatar, online: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName?.trim().isNotEmpty == true
                            ? profile.displayName!
                            : 'Nimzo User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Nimzo ID ${profile.nimzoId}  ·  Lv ${profile.level}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (profile.vipLevel > 0 || profile.svipLevel > 0)
                        Text(
                          profile.svipLevel > 0 ? 'SVIP' : 'VIP',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    try {
                      final container = ProviderScope.containerOf(
                        context,
                        listen: false,
                      );
                      final following =
                          container
                              .read(isFollowingProvider(profile.id))
                              .valueOrNull ??
                          false;
                      final fr = container.read(followRepositoryProvider);
                      following
                          ? await fr.unfollow(profile.id)
                          : await fr.follow(profile.id);
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Follow'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await ProviderScope.containerOf(
                        context,
                        listen: false,
                      ).read(friendRepositoryProvider).request(profile.id);
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Add'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showGiftSheet(context, room.id, profile.id);
                  },
                  icon: const Icon(Icons.card_giftcard_outlined),
                  label: const Text('Gift'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await ProviderScope.containerOf(context, listen: false)
                          .read(roomRepositoryProvider)
                          .modMuteSeat(room.id, seat.seatNo, !seat.muted);
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  icon: Icon(seat.muted ? Icons.mic : Icons.mic_off_outlined),
                  label: Text(seat.muted ? 'Unmute' : 'Mute'),
                ),
                if (isOwner)
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      try {
                        await ProviderScope.containerOf(context, listen: false)
                            .read(roomRepositoryProvider)
                            .kick(room.id, profile.id);
                      } catch (e) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Kick'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoomGiftFeed extends ConsumerWidget {
  final String roomId;
  const _RoomGiftFeed({required this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(roomGiftEventProvider(roomId))
        .when(
          loading: () => const SizedBox(height: 42),
          error: (_, __) => const SizedBox(height: 42),
          data: (events) {
            if (events.isEmpty) return const SizedBox(height: 42);
            final e = events.first;
            return Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .90),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .65)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gift sent  •  x${e['quantity'] ?? 1}  •  ${e['total_coins'] ?? 0} coins',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }
}
