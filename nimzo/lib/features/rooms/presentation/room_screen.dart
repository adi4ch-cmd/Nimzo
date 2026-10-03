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
  final _chat = TextEditingController();
  String? _receiver;
  bool _micOn = false, _joined = false;

  @override
  void initState() {
    super.initState();
    _actions = ref.read(roomActionsProvider);
    Future.microtask(_enter);
  }

  Future<void> _enter({String? password}) async {
    try {
      await _actions.enter(widget.roomId, password: password);
      // Room chat is ephemeral: every new room session starts clean.
      try { await ref.read(roomChatRepositoryProvider).clear(widget.roomId); } catch (_) {}
      if (mounted) setState(() => _joined = true);
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

  Future<String?> _askPassword() {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (d) => AlertDialog(
      title: const Text('Room password'),
      content: TextField(controller: c, obscureText: true),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Join'))],
    ));
  }

  @override
  void dispose() {
    _chat.dispose();
    if (_joined) {
      // Room chat is ephemeral: clear it when the current room session ends.
      ref.read(roomChatRepositoryProvider).clear(widget.roomId).catchError((_) {});
      _actions.exit(widget.roomId);
    }
    super.dispose();
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.roomId));
    final seats = ref.watch(seatsProvider(widget.roomId));
    final speaking = ref.watch(speakingProvider).valueOrNull ?? {};
    final online = ref.watch(onlineCountProvider(widget.roomId)).valueOrNull ?? 0;
    final me = ref.watch(currentUserIdProvider);

    ref.listen(roomGiftEventProvider(widget.roomId), (_, n) {
      final l = n.valueOrNull;
      if (l != null && l.isNotEmpty) GiftAnimationService.play(context, 'Gift x${l.first['quantity']}', giftId: l.first['gift_id']?.toString(), quantity: (l.first['quantity'] as num?)?.toInt() ?? 1);
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
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(roomProvider(widget.roomId))),
            data: (rm) => DefaultTextStyle.merge(
              style: TextStyle(color: theme.text),
              child: IconTheme(
                data: IconThemeData(color: theme.text),
                child: Column(children: [
                  Consumer(builder: (context, ref, _) {
                    final owner = ref.watch(roomOwnerProfileProvider(rm.id)).valueOrNull;
                    final db = ref.watch(supabaseProvider);
                    final roomAvatar = storageUrl(db, 'avatars', rm.avatarPath) ?? storageUrl(db, 'avatars', owner?.avatarPath);
                    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .86), borderRadius: BorderRadius.circular(18)), child: Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                      NimzoAvatar(radius: 24, url: roomAvatar, online: true),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rm.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
                        Text('ID ${rm.roomNo}  ·  $online online', style: const TextStyle(fontSize: 12)),
                        Row(children: [const Icon(Icons.card_giftcard_rounded, size: 13), const SizedBox(width: 4), Expanded(child: Text('Lifetime Gifting: ${rm.lifetimeGiftCoins} coins', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))]),
                      ])),
                      IconButton(icon: const Icon(Icons.share_outlined), onPressed: () { Clipboard.setData(ClipboardData(text: 'nimzo://room/${rm.id}')); _snack('Room link copied'); }),
                      IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/room/${rm.id}/settings?owner=$isOwner')),
                    ]));
                  }),
                  seats.when(
                    loading: () => const SizedBox(height: 180, child: LoadingView()),
                    error: (e, _) => SizedBox(height: 180, child: ErrorView(message: '$e', onRetry: () => ref.invalidate(seatsProvider(widget.roomId)))),
                    data: (list) {
                      final byNo = {for (final s in list) s.seatNo: s};
                      final profiles = ref.watch(roomSeatProfilesProvider(widget.roomId)).valueOrNull ?? const <String, Profile>{};
                      return GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 5,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4), mainAxisSpacing: 10, crossAxisSpacing: 6, childAspectRatio: .78,
                        children: [for (var i = 1; i <= 10; i++) _Seat(
                          seat: byNo[i] ?? MicSeat(seatNo: i), profile: byNo[i]?.userId == null ? null : profiles[byNo[i]!.userId],
                          speaking: speaking, selected: byNo[i]?.userId == _receiver && _receiver != null,
                          onTap: () {
                            final s = byNo[i] ?? MicSeat(seatNo: i);
                            if (s.userId == null) { if (!s.locked) _actions.seat(widget.roomId, i).catchError((e) => _snack('$e')); }
                            else {
                              setState(() => _receiver = s.userId);
                              final profile = profiles[s.userId];
                              if (profile != null) _openUserSheet(context, rm, s, profile, isOwner);
                            }
                          })],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _RoomGiftFeed(roomId: widget.roomId),
                  Expanded(child: _ChatList(roomId: widget.roomId)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
                    Expanded(child: TextField(controller: _chat, style: TextStyle(color: theme.text), decoration: const InputDecoration(hintText: 'Say something', isDense: true))),
                    IconButton(icon: const Icon(Icons.send), onPressed: () async {
                      final t = _chat.text.trim();
                      if (t.isEmpty) return;
                      _chat.clear();
                      try { await ref.read(roomChatRepositoryProvider).send(widget.roomId, t); } catch (e) { _snack('$e'); }
                    }),
                  ])),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    IconButton(tooltip: 'Gift', icon: const Icon(Icons.card_giftcard), onPressed: () {
                      if (_receiver == null) return _snack('Tap a seat to choose who receives the gift');
                      showGiftSheet(context, widget.roomId, _receiver!);
                    }),
                    IconButton(tooltip: 'Mic', icon: Icon(_micOn ? Icons.mic : Icons.mic_off), onPressed: () async {
                      setState(() => _micOn = !_micOn);
                      await ref.read(voiceServiceProvider).setMicEnabled(_micOn);
                    }),
                    IconButton(tooltip: 'Leave seat', icon: const Icon(Icons.event_seat_outlined), onPressed: () => _actions.unseat(widget.roomId)),
                    IconButton(tooltip: 'Game', icon: const Icon(Icons.sports_esports_outlined), onPressed: () => context.push('/games-play?room=${rm.id}')),


                    IconButton(tooltip: 'More', icon: const Icon(Icons.more_horiz), onPressed: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
                      ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Follow room'), onTap: () async { Navigator.pop(context); try { await ref.read(roomRepositoryProvider).followRoom(rm.id, true); _snack('Room followed'); } catch (e) { _snack('$e'); } }),
                      ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report room'), onTap: () async { Navigator.pop(context); try { await ref.read(roomSettingsRepositoryProvider).report(rm.id, 'user_report'); _snack('Report sent'); } catch (e) { _snack('$e'); } }),
                    ])))),
                  ]),
                ]),
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
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(roomChatProvider(roomId)).when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Chat unavailable', style: Theme.of(context).textTheme.bodySmall)),
        data: (l) => ListView(reverse: true, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
          for (final m in l) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(m.body)),
        ]),
      );
}

class _Seat extends StatelessWidget {
  final MicSeat seat;
  final Profile? profile;
  final Set<String> speaking;
  final bool selected;
  final VoidCallback onTap;
  const _Seat({required this.seat, required this.profile, required this.speaking, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = seat.userId != null && speaking.contains(seat.userId);
    final db = Supabase.instance.client;
    final avatar = storageUrl(db, 'avatars', profile?.avatarPath);
    final name = profile?.displayName?.trim().isNotEmpty == true ? profile!.displayName! : (profile?.nimzoId.toString() ?? 'User');
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active || selected ? const Color(0xFF22C55E) : const Color(0x40808080), width: active ? 3 : selected ? 2 : 1)),
          child: NimzoAvatar(radius: 22, url: avatar, online: seat.userId != null),
        ),
        const SizedBox(height: 2),
        Text(seat.userId == null ? '${seat.seatNo}' : name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (seat.muted) const Icon(Icons.mic_off, size: 12, color: Color(0xFFEF4444)),
      ]),
    );
  }
}

Future<void> _openUserSheet(BuildContext context, Room room, MicSeat seat, Profile profile, bool isOwner) async {
  final db = Supabase.instance.client;
  final avatar = storageUrl(db, 'avatars', profile.avatarPath);
  await showModalBottomSheet(
    context: context, showDragHandle: true,
    builder: (sheetContext) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          NimzoAvatar(radius: 30, url: avatar, online: true),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.displayName?.trim().isNotEmpty == true ? profile.displayName! : 'Nimzo User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Nimzo ID ${profile.nimzoId}  ·  Lv ${profile.level}', style: Theme.of(context).textTheme.bodySmall),
            if (profile.vipLevel > 0 || profile.svipLevel > 0) Text(profile.svipLevel > 0 ? 'SVIP' : 'VIP', style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              try {
                final container = ProviderScope.containerOf(context, listen: false);
                final following = container.read(isFollowingProvider(profile.id)).valueOrNull ?? false;
                final fr = container.read(followRepositoryProvider);
                following ? await fr.unfollow(profile.id) : await fr.follow(profile.id);
              } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            },
            icon: const Icon(Icons.person_add_alt_1), label: const Text('Follow'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              try { await ProviderScope.containerOf(context, listen: false).read(friendRepositoryProvider).request(profile.id); }
              catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            },
            icon: const Icon(Icons.group_add_outlined), label: const Text('Add'),
          ),
          OutlinedButton.icon(
            onPressed: () { Navigator.pop(sheetContext); showGiftSheet(context, room.id, profile.id); },
            icon: const Icon(Icons.card_giftcard_outlined), label: const Text('Gift'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              try { await ProviderScope.containerOf(context, listen: false).read(roomRepositoryProvider).modMuteSeat(room.id, seat.seatNo, !seat.muted); }
              catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            },
            icon: Icon(seat.muted ? Icons.mic : Icons.mic_off_outlined), label: Text(seat.muted ? 'Unmute' : 'Mute'),
          ),
          if (isOwner) OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(sheetContext);
              try { await ProviderScope.containerOf(context, listen: false).read(roomRepositoryProvider).kick(room.id, profile.id); }
              catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
            },
            icon: const Icon(Icons.person_remove_outlined), label: const Text('Kick'),
          ),
        ]),
      ]),
    )),
  );
}


class _RoomGiftFeed extends ConsumerWidget {
  final String roomId;
  const _RoomGiftFeed({required this.roomId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(roomGiftEventProvider(roomId)).when(
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
          child: Row(children: [
            const Icon(Icons.card_giftcard_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Gift sent  •  x${e['quantity'] ?? 1}  •  ${e['total_coins'] ?? 0} coins',
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
          ]),
        );
      },
    );
  }
}
