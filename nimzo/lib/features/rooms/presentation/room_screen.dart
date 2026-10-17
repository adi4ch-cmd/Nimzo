// ignore_for_file: prefer_interpolation_to_compose_strings
import '../../profile/profile_repository.dart';
import '../../store/store_badge.dart';
import '../../gifts/verified_gift_broadcast.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../gifts/gift_sheet.dart';
import '../../gifts/yo2_gift_ui.dart';
import '../../games/games_catalog_screen.dart';
import '../../home/pk_battles_screen.dart';
import '../../games/room_game_host.dart';
import '../../voice/voice_controller.dart';
import '../../voice/vivox_voice_service.dart';
import '../data/room_chat_repository.dart';
import '../domain/room.dart';
import '../domain/room_theme.dart';
import 'room_controller.dart';
import 'room_session.dart';
import 'room_user_sheet.dart';
import 'room_overlays.dart';
import '../rocket/room_rocket_widgets.dart';
import '../diamond/room_diamond_repository.dart';
import '../../../core/widgets/master_ui.dart';
import '../../../core/utils/formatters.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});
  @override
  ConsumerState<RoomScreen> createState() => _State();
}

class _State extends ConsumerState<RoomScreen> {
  final text = TextEditingController();
  final gameHost = GlobalKey<RoomGameHostState>();
  Timer? _activityTimer;
  Timer? _voiceDropTimer;
  bool joining = true, joined = false, mic = false, leaving = false;
  bool _allowPop = false;
  bool _exitPromptVisible = false;
  bool micBusy = false;
  bool chatBusy = false;
  String? failure;
  late final RoomSession session;
  @override
  void initState() {
    super.initState();
    final repository = ref.read(roomRepositoryProvider),
        voice = ref.read(voiceServiceProvider),
        me = ref.read(currentUserIdProvider);
    session = RoomSession(
      joinRoom: () async {
        final room = await repository.get(widget.roomId);
        String? password;
        if (!mounted) throw StateError('Room closed');
        if (room.isPrivate && room.ownerId != me) {
          password = await showDialog<String>(
            context: context,
            builder: (c) => _PasswordDialog(),
          );
          if (password == null || !mounted)
            throw StateError('Room join cancelled');
        }
        await repository.join(widget.roomId, password: password);
      },
      leaveRoom: () => repository.leave(widget.roomId),
      joinVoice: () => voice.join(widget.roomId, ''),
      leaveVoice: voice.leave,
    );
    Future.microtask(join);
  }

  Future<void> join() async {
    if (!mounted || session.closed) return;
    _voiceDropTimer?.cancel();
    setState(() {
      joining = true;
      failure = null;
      mic = false;
    });
    try {
      await session.join();
      joined = session.joined;
      if (joined) _startActivityTracking();
    } catch (error) {
      joined = session.joined;
      failure = joined
          ? error is VoiceConnectionFailure
              ? error.message.toString()
              : 'Voice connection failed (${error.runtimeType}). Retry voice.'
          : 'Unable to enter this room. Please retry.';
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(seconds: 70), (_) async {
      if (!mounted || !joined || leaving) return;
      try {
        final gained =
            await ref.read(roomRepositoryProvider).touchActivity(widget.roomId);
        if (!mounted || gained <= 0) return;
        final user = ref.read(currentUserIdProvider);
        if (user != null) ref.invalidate(profileProvider(user));
      } catch (_) {
        // Connection recovery will retry on the next tick; we never fabricate
        // activity points client-side.
      }
    });
  }

  Future<void> leave() async {
    if (leaving) return;
    _voiceDropTimer?.cancel();
    leaving = true;
    _activityTimer?.cancel();
    try {
      await session.close();
      joined = false;
      if (mounted) {
        ref.invalidate(onlineCountProvider(widget.roomId));
        ref.invalidate(roomSeatProfilesProvider(widget.roomId));
        ref.invalidate(roomChatProvider(widget.roomId));
        ref.invalidate(seatsProvider(widget.roomId));
        ref.invalidate(myRoomsProvider);
      }
    } finally {
      leaving = false;
    }
  }

  /// Explicit header exit follows the reference confirmation design.
  /// A cancellation does not drop the Vivox connection or room membership.
  Future<void> _confirmRoomExit() async {
    if (!mounted || leaving || _allowPop || _exitPromptVisible) return;
    _exitPromptVisible = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xfff9f5ff),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xffa246ef), size: 30),
            SizedBox(width: 10),
            Expanded(child: Text('Leave audio room?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          ],
        ),
        content: const Text(
          'You will leave the microphones and voice session. '
          'Your NIMZO account, room and coins will remain saved.',
          style: TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Stay')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffa246ef)),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Leave room')),
        ],
      ),
    );
    } finally {
      _exitPromptVisible = false;
    }
    if (confirmed == true && mounted) await _exitRoom();
  }

  Future<void> _exitRoom() async {
    if (leaving || _allowPop || !mounted) return;
    try {
      await leave();
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Room exit not confirmed. Retry to leave safely.'),
          action: SnackBarAction(
              label: 'Retry', onPressed: () => unawaited(_exitRoom())),
        ),
      );
    }
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _voiceDropTimer?.cancel();
    text.dispose();
    unawaited(session.close().catchError((_) {}));
    super.dispose();
  }

  Future<void> action(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action could not be completed. Please retry.'),
          ),
        );
    }
  }

  Widget _artButton(String group, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xfffff2db),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ReferenceArtwork(group, 0, size: 38),
        ),
      );

  Future<void> toggleMic() => action(() async {
        if (micBusy) return;
        final enabled = !mic;
        final voice = ref.read(voiceServiceProvider);
        setState(() => micBusy = true);
        try {
          await voice.setMicEnabled(enabled);
          if (mounted && ref.read(voiceConnectedProvider).valueOrNull == true) {
            setState(() => mic = enabled);
          }
        } finally {
          if (mounted) setState(() => micBusy = false);
        }
      });

  Future<void> sendMessage() => action(() async {
        if (chatBusy) return;
        final submitted = text.text;
        if (submitted.trim().isEmpty) return;
        final repository = ref.read(roomChatRepositoryProvider);
        setState(() => chatBusy = true);
        try {
          await repository.send(widget.roomId, submitted.trim());
          if (mounted && text.text == submitted) text.clear();
        } finally {
          if (mounted) setState(() => chatBusy = false);
        }
      });

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.roomId)),
        seats = ref.watch(seatsProvider(widget.roomId)),
        profiles =
            ref.watch(roomSeatProfilesProvider(widget.roomId)).valueOrNull ??
                {};
    final me = ref.watch(currentUserIdProvider),
        speaking = ref.watch(speakingProvider).valueOrNull ?? <String>{};
    final connected = ref.watch(voiceConnectedProvider).valueOrNull ?? false;
    ref.listen(voiceConnectedProvider, (previous, next) {
      if (next.valueOrNull == true) {
        // The SDK may restore media automatically after a short network drop.
        _voiceDropTimer?.cancel();
        if (failure == 'Voice disconnected. Retry voice.' && !joining) {
          setState(() => failure = null);
        }
      } else if (previous?.valueOrNull == true &&
          next.valueOrNull == false &&
          joined &&
          !joining &&
          !leaving &&
          !session.closed) {
        // Taking a mic seat upgrades a muted Vivox session and deliberately
        // reconnects. It must not display a spurious room-wide failure.
        if (micBusy) return;
        _voiceDropTimer?.cancel();
        setState(() => mic = false);
        // Let Vivox's built-in network recovery run before offering a fresh
        // login. An immediate Retry can race the SDK's recovery process.
        _voiceDropTimer = Timer(const Duration(seconds: 6), () {
          if (!mounted ||
              session.closed ||
              leaving ||
              joining ||
              ref.read(voiceConnectedProvider).valueOrNull == true) return;
          setState(() => failure = 'Voice disconnected. Retry voice.');
        });
      }
    });
    ref.listen(seatsProvider(widget.roomId), (_, next) {
      final occupied =
          next.valueOrNull?.any((s) => s.userId == me && !s.muted) ?? false;
      if (mic && !occupied) {
        mic = false;
        final voice = ref.read(voiceServiceProvider);
        unawaited(
          voice.setMicEnabled(false).catchError((Object _) async {
            await voice.leave();
          }).catchError((Object _) {}),
        );
      }
    });
    return RoomRocketHost(
      roomId: widget.roomId,
      enabled: joined,
      child: RoomGameHost(
        key: gameHost,
        roomId: widget.roomId,
        voiceConnected: connected,
        micEnabled: mic,
        onMic: !connected || micBusy ? null : toggleMic,
        child: PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmRoomExit());
          },
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: RoomTheme.byId(
                  room.valueOrNull?.theme ?? 'nimzo_white',
                ).gradient.last,
                appBar: AppBar(
                  backgroundColor: RoomTheme.byId(
                    room.valueOrNull?.theme ?? 'nimzo_white',
                  ).gradient.first,
                  foregroundColor: RoomTheme.byId(
                    room.valueOrNull?.theme ?? 'nimzo_white',
                  ).text,
                  toolbarHeight: 64,
                  titleSpacing: 0,
                  actions: [
                    IconButton(
                      key: const ValueKey('room-live-pk'),
                      tooltip: 'Room PK Battle',
                      onPressed: joined ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PkBattlesScreen(),
                        ),
                      ) : null,
                      icon: const Icon(Icons.bolt_rounded,
                        size: 25, color: Color(0xffa84bdc)),
                    ),
                    IconButton(
                      key: const ValueKey('room-confirm-exit'),
                      tooltip: 'Leave audio room',
                      onPressed: leaving ? null : _confirmRoomExit,
                      icon: const Icon(Icons.close_rounded, size: 26),
                    ),
                  ],
                  title: InkWell(
                    onTap: room.valueOrNull == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RoomProfilePage(room: room.valueOrNull!),
                              ),
                            ),
                    child: Row(
                      children: [
                        ReferenceRoomAvatar(
                          key: const ValueKey('room-header-avatar'),
                          size: 54,
                          url: room.valueOrNull?.avatarPath == null
                              ? null
                              : ref
                                  .read(supabaseProvider)
                                  .storage
                                  .from('room-images')
                                  .getPublicUrl(
                                    room.valueOrNull!.avatarPath!,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.valueOrNull?.name ?? 'Voice Room',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'ID:${room.valueOrNull?.roomNo ?? '—'} · ${ref.watch(onlineCountProvider(widget.roomId)).valueOrNull?.toString() ?? '—'} online',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: RoomTheme.byId(
                                    room.valueOrNull?.theme ?? 'nimzo_white',
                                  ).text.withValues(alpha: .8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(32),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: NimzoStyle.orange.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                  size: 17, color: NimzoStyle.orange),
                                const SizedBox(width: 6),
                                Text(
                                  compactNumber(
                                    room.valueOrNull?.lifetimeGiftCoins ?? 0,
                                  ),
                                  key: const ValueKey('room-header-total-gifting'),
                                  style: const TextStyle(
                                    color: NimzoStyle.royal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      if (joining) const LinearProgressIndicator(),
                      if (room.hasError)
                        DataFailure(
                          onRetry: () =>
                              ref.invalidate(roomProvider(widget.roomId)),
                        ),
                      if (seats.hasError)
                        DataFailure(
                          message: 'Seats could not be loaded.',
                          onRetry: () =>
                              ref.invalidate(seatsProvider(widget.roomId)),
                        ),
                      if (failure != null)
                        DataFailure(message: failure!, onRetry: join),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 10,
                        ),
                        child: Column(
                          children: [
                            for (var row = 0; row < 2; row++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: row == 0 ? 14 : 0,
                                ),
                                child: Row(
                                  children: [
                                    for (var col = 0; col < 5; col++)
                                      Expanded(
                                        child: Builder(
                                          builder: (c) {
                                            final n = row * 5 + col + 1,
                                                s = seats.valueOrNull
                                                        ?.where(
                                                          (s) => s.seatNo == n,
                                                        )
                                                        .firstOrNull ??
                                                    MicSeat(seatNo: n),
                                                p = profiles[s.userId];
                                            return InkWell(
                                              onTap: !joined ||
                                                      !seats.hasValue ||
                                                      (s.locked &&
                                                          s.userId == null)
                                                  ? null
                                                  : () => action(() async {
                                                        if (s.userId == null) {
                                                          await ref
                                                              .read(
                                                                roomRepositoryProvider,
                                                              )
                                                              .takeSeat(
                                                                widget.roomId,
                                                                n,
                                                              );
                                                        } else {
                                                          await showDialog<
                                                              void>(
                                                            context: context,
                                                            builder: (_) =>
                                                                Dialog(
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              insetPadding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 18,
                                                                vertical: 24,
                                                              ),
                                                              child:
                                                                  RoomUserSheet(
                                                                roomId: widget
                                                                    .roomId,
                                                                userId:
                                                                    s.userId!,
                                                                seatNo: n,
                                                                muted: s.muted,
                                                                onMention:
                                                                    (name) {
                                                                  final mention =
                                                                      '@$name ';
                                                                  text.value =
                                                                      TextEditingValue(
                                                                    text: mention +
                                                                        text.text,
                                                                    selection:
                                                                        TextSelection
                                                                            .collapsed(
                                                                      offset: mention
                                                                          .length,
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }),
                                              child: Column(
                                                children: [
                                                  if (s.userId == null)
                                                    DashedCircle(
                                                      child: Container(
                                                        width: 46,
                                                        height: 46,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient:
                                                              LinearGradient(
                                                            colors: [
                                                              Color(0xffac96ea),
                                                              Color(0xff8265d2),
                                                            ],
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          s.locked
                                                              ? Icons.lock_outline_rounded
                                                              : Icons.mic_none_rounded,
                                                          size: 23,
                                                          color:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(
                                                            2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: speaking
                                                                      .contains(
                                                                s.userId,
                                                              )
                                                                  ? NimzoStyle
                                                                      .primary
                                                                  : Colors
                                                                      .transparent,
                                                              width: 2,
                                                            ),
                                                          ),
                                                          child: NimzoAvatar(
                                                            name:
                                                                p?.displayName ??
                                                                    'N',
                                                            size: 48,
                                                            url: p?.avatarPath ==
                                                                    null
                                                                ? null
                                                                : ref
                                                                    .read(
                                                                      supabaseProvider,
                                                                    )
                                                                    .storage
                                                                    .from(
                                                                      'avatars',
                                                                    )
                                                                    .getPublicUrl(
                                                                      p!.avatarPath!,
                                                                    ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          right: -8,
                                                          bottom: -5,
                                                          child:
                                                              EquippedRoyalMedal(
                                                            userId: s.userId!,
                                                            compact: true,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    p?.displayName ?? '$n',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: RoomTheme.byId(
                                                        room.valueOrNull?.theme
                                                          ?? 'nimzo_white',
                                                      ).text.withValues(alpha: .88),
                                                    ),
                                                  ),
                                                  if (s.muted)
                                                    Icon(
                                                      LucideIcons.micOff,
                                                      size: 12,
                                                      color: RoomTheme.byId(
                                                        room.valueOrNull?.theme
                                                          ?? 'nimzo_white',
                                                      ).text,
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .85,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: NimzoStyle.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              room.valueOrNull?.rules?.isNotEmpty == true
                                  ? room.valueOrNull!.rules!
                                  : 'Please respect each other and chat in a decent manner.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AsyncContent(
                                value: ref.watch(
                                  roomChatProvider(widget.roomId),
                                ),
                                onRetry: () => ref.invalidate(
                                  roomChatProvider(widget.roomId),
                                ),
                                builder: (messages) => ListView(
                                  reverse: true,
                                  padding: const EdgeInsets.all(14),
                                  children: [
                                    // Server RLS uses joined_at. A phone clock cannot define this boundary.
                                    for (final msg in messages)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.sizeOf(context)
                                                    .width *
                                                .85,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: NimzoStyle.surface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  profiles[msg.userId]
                                                          ?.displayName ??
                                                      'Nimzo user',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: NimzoStyle.primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  )),
                                              Text(
                                                msg.body,
                                                style: const TextStyle(
                                                  color: NimzoStyle.ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 12,
                              child: Column(
                                children: [
                                  _artButton(
                                    'chest',
                                    () => showReferenceSheet(
                                      context,
                                      const TreasureSheet(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: !joined
                                        ? null
                                        : () => showModalBottomSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: const Color(0xff0c1728),
                                              barrierColor: Colors.black.withValues(alpha: .72),
                                              shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(24),
                                                ),
                                              ),
                                              builder: (_) => SafeArea(
                                                child: Padding(
                                                  padding: const EdgeInsets.fromLTRB(17, 18, 17, 12),
                                                  child: RoomRocketSheet(roomId: widget.roomId),
                                                ),
                                              ),
                                            ),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: NimzoStyle.surface,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/room_rocket/posters/rocket_stage_${((joined ? ref.watch(roomDiamondStatusProvider(widget.roomId)).valueOrNull?.activeStage ?? 0 : 0) + 1)}.png',
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.contain,
                                          ),
                                          Text(
                                            'L' +
                                                ((joined
                                                            ? ref
                                                                    .watch(
                                                                      roomDiamondStatusProvider(
                                                                          widget
                                                                              .roomId),
                                                                    )
                                                                    .valueOrNull
                                                                    ?.activeStage ??
                                                                0
                                                            : 0) +
                                                        1)
                                                    .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: NimzoStyle.line),
                          ),
                        ),
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                              ? 0
                              : 8,
                        ),
                        child: IconButtonTheme(
                          data: IconButtonThemeData(
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 34),
                              maximumSize: const Size(30, 34),
                              iconSize: 20,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Party Tools',
                                onPressed: () => showPartyTools(
                                  context,
                                  roomId: widget.roomId,
                                ),
                                icon: const ReferenceIcon('grid'),
                              ),
                              IconButton(
                                tooltip: 'Voice and Effect',
                                onPressed: () => showReferenceSheet(
                                  context,
                                  VoiceEffectsSheet(
                                    micEnabled: mic,
                                    onMic: !connected || micBusy
                                        ? null
                                        : toggleMic,
                                  ),
                                ),
                                icon: const ReferenceIcon('spk'),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: text,
                                  maxLength: 500,
                                  onSubmitted: (_) => !joined || chatBusy
                                      ? null
                                      : sendMessage(),
                                  decoration: InputDecoration(
                                    suffixIconConstraints:
                                        const BoxConstraints.tightFor(
                                      width: 30,
                                      height: 34,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Send',
                                      onPressed: !joined || chatBusy
                                          ? null
                                          : sendMessage,
                                      icon: const ReferenceIcon(
                                        'send',
                                        size: 18,
                                        color: NimzoStyle.primary,
                                      ),
                                    ),
                                    hintText: 'Say hi…',
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Microphone',
                                onPressed:
                                    !connected || micBusy ? null : toggleMic,
                                icon: Icon(
                                  mic ? LucideIcons.mic : LucideIcons.micOff,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Games',
                                onPressed: () => showRoomGamesSheet(
                                  context,
                                  widget.roomId,
                                  onSelected: (slug) =>
                                      gameHost.currentState?.open(slug),
                                ),
                                icon: const ReferenceIcon('game'),
                              ),
                              IconButton(
                                tooltip: 'Gift',
                                onPressed: !joined || me == null
                                    ? null
                                    : () async {
                                        final recipients = [
                                          me,
                                          ...profiles.keys.where(
                                            (k) => k != me,
                                          ),
                                        ];
                                        final id =
                                            await showModalBottomSheet<String>(
                                          context: context,
                                          builder: (c) => SafeArea(
                                            child: ListView(
                                              shrinkWrap: true,
                                              children: [
                                                for (final id in recipients)
                                                  ListTile(
                                                    title: Text(
                                                      id == me
                                                          ? 'Myself'
                                                          : profiles[id]
                                                                  ?.displayName ??
                                                              'Nimzo user',
                                                    ),
                                                    onTap: () => Navigator.pop(
                                                      c,
                                                      id,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (id != null && context.mounted)
                                          showRoomGiftSheet(
                                            context,
                                            widget.roomId,
                                            id,
                                          );
                                      },
                                icon: const Yo2GiftPanelArt(
                                  'ic_capsule_mic_gift.webp',
                                  width: 26,
                                  height: 26,
                                  fallback: ReferenceIcon(
                                    'gift',
                                    color: NimzoStyle.pink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (joined)
                Positioned.fill(
                  child: VerifiedGiftBroadcast(
                    roomId: widget.roomId,
                    countryCode: room.valueOrNull?.country ?? '',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  @override
  State<_PasswordDialog> createState() => _PasswordState();
}

class _PasswordState extends State<_PasswordDialog> {
  final password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Room password'),
        content: TextField(controller: password, obscureText: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Join'),
          ),
        ],
      );
}
