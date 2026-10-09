import '../../vip/phoenix_widgets.dart';
import '../../vip/phoenix_room_entry.dart';
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
import '../../games/room_game_host.dart';
import '../../voice/voice_controller.dart';
import '../../voice/vivox_voice_service.dart';
import '../data/room_chat_repository.dart';
import '../domain/room.dart';
import 'room_controller.dart';
import 'room_session.dart';
import 'room_user_sheet.dart';
import 'room_overlays.dart';
import '../diamond/room_diamond_widgets.dart';
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
  bool joining = true, joined = false, mic = false, leaving = false;
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
    setState(() {
      joining = true;
      failure = null;
      mic = false;
    });
    try {
      await session.join();
      joined = session.joined;
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

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    await session.close();
    joined = false;
  }

  @override
  void dispose() {
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
        color: const Color(0xfff1e6ff),
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
      if (previous?.valueOrNull == true &&
          next.valueOrNull == false &&
          joined &&
          !joining &&
          !leaving &&
          !session.closed) {
        setState(() {
          mic = false;
          failure = 'Voice disconnected. Retry voice.';
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
          voice
              .setMicEnabled(false)
              .catchError((Object _) async {
                await voice.leave();
              })
              .catchError((Object _) {}),
        );
      }
    });
    return RoomDiamondHost(
      roomId: widget.roomId,
      enabled: joined,
      child: RoomGameHost(
        key: gameHost,
        roomId: widget.roomId,
        voiceConnected: connected,
        micEnabled: mic,
        onMic: !connected || micBusy ? null : toggleMic,
        child: PopScope(
          canPop: !leaving,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) unawaited(leave().catchError((_) {}));
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  titleSpacing: 0,
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
                          size: 38,
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: NimzoStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Text(
                          compactNumber(
                            room.valueOrNull?.lifetimeGiftCoins ?? 0,
                          ),
                          style: const TextStyle(
                            color: NimzoStyle.pink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                                                s =
                                                    seats.valueOrNull
                                                        ?.where(
                                                          (s) => s.seatNo == n,
                                                        )
                                                        .firstOrNull ??
                                                    MicSeat(seatNo: n),
                                                p = profiles[s.userId];
                                            return InkWell(
                                              onTap:
                                                  !joined ||
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
                                                        await showModalBottomSheet<
                                                          void
                                                        >(
                                                          context: context,
                                                          isScrollControlled:
                                                              true,
                                                          builder: (_) =>
                                                              RoomUserSheet(
                                                                roomId: widget
                                                                    .roomId,
                                                                userId:
                                                                    s.userId!,
                                                                seatNo: n,
                                                                muted: s.muted,
                                                              ),
                                                        );
                                                      }
                                                    }),
                                              child: Column(
                                                children: [
                                                  if (s.userId == null)
                                                    DashedCircle(
                                                      child: ReferenceIcon(
                                                        s.locked
                                                            ? 'lock'
                                                            : 'mic',
                                                        size: 22,
                                                        color:
                                                            NimzoStyle.primary,
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color:
                                                              speaking.contains(
                                                                s.userId,
                                                              )
                                                              ? NimzoStyle
                                                                    .primary
                                                              : Colors
                                                                    .transparent,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: PhoenixDecoration(
                                                        userId: s.userId,
                                                        avatar: true,
                                                        child: NimzoAvatar(
                                                          name:
                                                              p?.displayName ??
                                                              'N',
                                                          size: 48,
                                                          url:
                                                              p?.avatarPath ==
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
                                                    ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    p?.displayName ?? '$n',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: NimzoStyle.muted,
                                                    ),
                                                  ),
                                                  if (s.muted)
                                                    const Icon(
                                                      LucideIcons.micOff,
                                                      size: 12,
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
                              color: const Color(0xfff1e6ff),
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
                                        child: PhoenixDecoration(
                                          userId: msg.userId,
                                          child: Container(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  MediaQuery.sizeOf(context)
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
                                                PhoenixNameplate(
                                                  userId: msg.userId,
                                                  name:
                                                      profiles[msg.userId]
                                                          ?.displayName ??
                                                      'Nimzo user',
                                                  style: const TextStyle(
                                                    color: NimzoStyle.primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
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
                                        : () => showReferenceSheet(
                                            context,
                                            CrystalSheet(roomId: widget.roomId),
                                          ),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfff1e6ff),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: diamondArtwork(
                                        joined
                                            ? ref
                                                      .watch(
                                                        roomDiamondStatusProvider(
                                                          widget.roomId,
                                                        ),
                                                      )
                                                      .valueOrNull
                                                      ?.activeStage ??
                                                  0
                                            : 0,
                                        size: 38,
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
                                onPressed: !connected || micBusy
                                    ? null
                                    : toggleMic,
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
                                                        onTap: () =>
                                                            Navigator.pop(
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
                Positioned(
                  top: 140,
                  left: 0,
                  right: 0,
                  child: PhoenixRoomEntry(roomId: widget.roomId),
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
