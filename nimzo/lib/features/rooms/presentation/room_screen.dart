import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../gifts/gift_sheet.dart';
import '../../voice/voice_controller.dart';
import '../data/room_chat_repository.dart';
import '../domain/room.dart';
import 'room_controller.dart';
import 'room_session.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});
  @override
  ConsumerState<RoomScreen> createState() => _State();
}

class _State extends ConsumerState<RoomScreen> {
  final text = TextEditingController();
  DateTime? entered;
  bool joining = true, joined = false, mic = false, leaving = false;
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
    });
    try {
      await session.join();
      joined = session.joined;
      entered = session.enteredAt;
    } catch (_) {
      joined = session.joined;
      entered = session.enteredAt;
      failure = joined
          ? 'Voice could not connect. Retry voice.'
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
    ref.listen(seatsProvider(widget.roomId), (_, next) {
      final occupied =
          next.valueOrNull?.any((s) => s.userId == me && !s.muted) ?? false;
      if (mic && !occupied) {
        mic = false;
        unawaited(
          ref
              .read(voiceServiceProvider)
              .setMicEnabled(false)
              .catchError((_) {}),
        );
      }
    });
    return PopScope(
      canPop: !leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(leave().catchError((_) {}));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(room.valueOrNull?.name ?? 'Voice Room'),
          actions: [
            if (room.valueOrNull?.ownerId == me)
              IconButton(
                onPressed: () =>
                    context.push('/room/${widget.roomId}/settings'),
                icon: const Icon(LucideIcons.settings),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (joining) const LinearProgressIndicator(),
              if (room.hasError)
                DataFailure(
                  onRetry: () => ref.invalidate(roomProvider(widget.roomId)),
                ),
              if (seats.hasError)
                DataFailure(
                  message: 'Seats could not be loaded.',
                  onRetry: () => ref.invalidate(seatsProvider(widget.roomId)),
                ),
              if (failure != null)
                DataFailure(message: failure!, onRetry: join),
              if (room.valueOrNull != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      NimzoAvatar(
                        name: room.valueOrNull!.name,
                        size: 52,
                        url: room.valueOrNull!.avatarPath == null
                            ? null
                            : ref
                                .watch(supabaseProvider)
                                .storage
                                .from('room-images')
                                .getPublicUrl(room.valueOrNull!.avatarPath!),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.valueOrNull!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Lifetime gifts: ${room.valueOrNull!.lifetimeGiftCoins} coins',
                              style: const TextStyle(
                                fontSize: 12,
                                color: NimzoStyle.primary,
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ID:${room.valueOrNull?.roomNo ?? '—'} · ${ref.watch(onlineCountProvider(widget.roomId)).valueOrNull?.toString() ?? '—'} online',
                      ),
                    ),
                    Text(
                      connected ? 'Voice connected' : 'Voice disconnected',
                      style: const TextStyle(
                        fontSize: 11,
                        color: NimzoStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    for (var row = 0; row < 2; row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            for (var col = 0; col < 5; col++)
                              Expanded(
                                child: Builder(
                                  builder: (c) {
                                    final n = row * 5 + col + 1,
                                        s = seats.valueOrNull
                                                ?.where((s) => s.seatNo == n)
                                                .firstOrNull ??
                                            MicSeat(seatNo: n),
                                        p = profiles[s.userId];
                                    return InkWell(
                                      onTap: !joined ||
                                              !seats.hasValue ||
                                              s.locked
                                          ? null
                                          : () => action(() async {
                                                if (s.userId == null) {
                                                  await ref
                                                      .read(
                                                        roomRepositoryProvider,
                                                      )
                                                      .takeSeat(
                                                          widget.roomId, n);
                                                } else if (s.userId == me) {
                                                  await ref
                                                      .read(
                                                          voiceServiceProvider)
                                                      .setMicEnabled(false);
                                                  await ref
                                                      .read(
                                                        roomRepositoryProvider,
                                                      )
                                                      .leaveSeat(widget.roomId);
                                                } else {
                                                  context.push(
                                                    '/profile/${s.userId}',
                                                  );
                                                }
                                              }),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    speaking.contains(s.userId)
                                                        ? NimzoStyle.pink
                                                        : NimzoStyle.primary,
                                              ),
                                            ),
                                            child: s.userId == null
                                                ? const SizedBox.square(
                                                    dimension: 48,
                                                    child: Icon(
                                                      LucideIcons.mic,
                                                      color: NimzoStyle.primary,
                                                    ),
                                                  )
                                                : NimzoAvatar(
                                                    name: p?.displayName ?? 'N',
                                                    size: 48,
                                                    url: p?.avatarPath == null
                                                        ? null
                                                        : ref
                                                            .read(
                                                              supabaseProvider,
                                                            )
                                                            .storage
                                                            .from('avatars')
                                                            .getPublicUrl(
                                                              p!.avatarPath!,
                                                            ),
                                                  ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            p?.displayName ?? '$n',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
              if (room.valueOrNull?.rules?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(room.valueOrNull!.rules!),
                ),
              Expanded(
                child: AsyncContent(
                  value: ref.watch(roomChatProvider(widget.roomId)),
                  onRetry: () =>
                      ref.invalidate(roomChatProvider(widget.roomId)),
                  builder: (messages) => ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(14),
                    children: [
                      for (final msg in messages.where(
                        (m) => entered != null && !m.at.isBefore(entered!),
                      ))
                        ReferenceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profiles[msg.userId]?.displayName ??
                                    'Nimzo user',
                                style: const TextStyle(
                                  color: NimzoStyle.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(msg.body),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  bottom: MediaQuery.viewInsetsOf(context).bottom > 0 ? 0 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: text,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Say hi…',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      onPressed: !joined
                          ? null
                          : () => action(() async {
                                final body = text.text.trim();
                                if (body.isEmpty) return;
                                await ref
                                    .read(roomChatRepositoryProvider)
                                    .send(widget.roomId, body);
                                text.clear();
                              }),
                      icon: const Icon(LucideIcons.send),
                    ),
                    IconButton(
                      tooltip: 'Microphone',
                      onPressed: !connected
                          ? null
                          : () => action(() async {
                                await ref
                                    .read(voiceServiceProvider)
                                    .setMicEnabled(!mic);
                                if (mounted) setState(() => mic = !mic);
                              }),
                      icon: Icon(mic ? LucideIcons.mic : LucideIcons.micOff),
                    ),
                    IconButton(
                      tooltip: 'Games',
                      onPressed: () =>
                          context.push('/games?room=${widget.roomId}'),
                      icon: const Icon(LucideIcons.gamepad2),
                    ),
                    IconButton(
                      tooltip: 'Gift',
                      onPressed: !joined || me == null
                          ? null
                          : () async {
                              final recipients = [
                                me,
                                ...profiles.keys.where((k) => k != me),
                              ];
                              final id = await showModalBottomSheet<String>(
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
                                                : profiles[id]?.displayName ??
                                                    'Nimzo user',
                                          ),
                                          onTap: () => Navigator.pop(c, id),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                              if (id != null && context.mounted)
                                showRoomGiftSheet(context, widget.roomId, id);
                            },
                      icon: const Icon(
                        LucideIcons.gift,
                        color: NimzoStyle.pink,
                      ),
                    ),
                  ],
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
