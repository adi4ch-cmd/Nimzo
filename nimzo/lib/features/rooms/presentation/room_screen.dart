import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (_joined) _actions.exit(widget.roomId);
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
      if (l != null && l.isNotEmpty) GiftAnimationService.play(context, 'Gift x${l.first['quantity']}');
    });

    final r = room.valueOrNull;
    final theme = RoomTheme.byId(r?.theme ?? 'nimzo_white');
    final isOwner = r != null && r.ownerId == me;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: room.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(roomProvider(widget.roomId))),
            data: (rm) => DefaultTextStyle.merge(
              style: TextStyle(color: theme.text),
              child: IconTheme(
                data: IconThemeData(color: theme.text),
                child: Column(children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rm.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis),
                      Text('ID ${rm.roomNo}  ·  $online online', style: const TextStyle(fontSize: 12)),
                      Text('Lifetime Gifting: ${rm.lifetimeGiftCoins} coins', style: const TextStyle(fontSize: 11)),
                    ])),
                    IconButton(icon: const Icon(Icons.share_outlined), onPressed: () { Clipboard.setData(ClipboardData(text: 'nimzo://room/${rm.id}')); _snack('Room link copied'); }),
                    IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/room/${rm.id}/settings?owner=$isOwner')),
                  ]),
                  seats.when(
                    loading: () => const SizedBox(height: 180, child: LoadingView()),
                    error: (e, _) => SizedBox(height: 180, child: ErrorView(message: '$e', onRetry: () => ref.invalidate(seatsProvider(widget.roomId)))),
                    data: (list) {
                      final byNo = {for (final s in list) s.seatNo: s};
                      return GridView.count(
                        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 5,
                        padding: const EdgeInsets.all(12), mainAxisSpacing: 12, crossAxisSpacing: 6, childAspectRatio: .75,
                        children: [for (var i = 1; i <= 10; i++) _Seat(
                          seat: byNo[i] ?? MicSeat(seatNo: i), speaking: speaking, selected: byNo[i]?.userId == _receiver && _receiver != null,
                          onTap: () {
                            final s = byNo[i] ?? MicSeat(seatNo: i);
                            if (s.userId == null) { if (!s.locked) _actions.seat(widget.roomId, i).catchError((e) => _snack('$e')); }
                            else setState(() => _receiver = s.userId);
                          })],
                      );
                    },
                  ),
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
        data: (l) => ListView(reverse: true, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final m in l) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(m.body)),
        ]),
      );
}

class _Seat extends StatelessWidget {
  final MicSeat seat;
  final Set<String> speaking;
  final bool selected;
  final VoidCallback onTap;
  const _Seat({required this.seat, required this.speaking, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = seat.userId != null && speaking.contains(seat.userId);
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active || selected ? const Color(0xFF22C55E) : const Color(0x40808080), width: active ? 3 : selected ? 2 : 1)),
          child: CircleAvatar(radius: 22, backgroundColor: const Color(0x22808080),
              child: Icon(seat.locked ? Icons.lock_outline : seat.userId == null ? Icons.add : Icons.person)),
        ),
        const SizedBox(height: 2),
        Text(seat.userId == null ? '${seat.seatNo}' : 'User', style: const TextStyle(fontSize: 11), maxLines: 1),
        if (seat.muted) const Icon(Icons.mic_off, size: 12, color: Color(0xFFEF4444)),
      ]),
    );
  }
}
