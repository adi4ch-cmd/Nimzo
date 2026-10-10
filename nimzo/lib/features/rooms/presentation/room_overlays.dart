import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/widgets/master_ui.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../wallet/wallet_screen.dart';
import '../domain/room.dart';
import 'room_controller.dart';
import '../diamond/room_diamond_widgets.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/room_chat_repository.dart';

const roomToolNames = [
  'Broadcast',
  'Gathering',
  'Room PK',
  'PK',
  'Wheel',
  'Mora',
  'Treasure',
  'Prize',
  'Calculator',
  'Vote',
  'Music',
  'Video',
  'Clean',
];

Future<void> showPartyTools(BuildContext context, {String? roomId}) async {
  final tool = await showReferenceSheet<int>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Party Tools',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 84 * MediaQuery.textScalerOf(context).scale(1),
          children: [
            for (var i = 0; i < roomToolNames.length; i++)
              InkWell(
                onTap: () => Navigator.pop(context, i),
                child: Column(
                  children: [
                    ReferenceArtwork('tool', i, size: 48),
                    const SizedBox(height: 4),
                    Text(
                      roomToolNames[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  if (tool == null || !context.mounted) return;
  if (tool == 6) {
    await showReferenceSheet(context, const TreasureSheet());
    return;
  }
  if (tool == 2 || tool == 3 || tool == 10) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomToolPage(title: roomToolNames[tool]),
      ),
    );
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  await showReferenceSheet(
    context,
    RoomToolForm(
      tool: roomToolNames[tool],
      onAnnounce: roomId == null
          ? null
          : (body) =>
              container.read(roomChatRepositoryProvider).send(roomId, body),
      onClear: roomId == null
          ? null
          : () => container.read(roomChatRepositoryProvider).clear(roomId),
    ),
  );
}

class RoomToolForm extends StatefulWidget {
  final String tool;
  final Future<void> Function(String)? onAnnounce;
  final Future<void> Function()? onClear;
  const RoomToolForm({
    super.key,
    required this.tool,
    this.onAnnounce,
    this.onClear,
  });
  @override
  State<RoomToolForm> createState() => _ToolFormState();
}

class _ToolFormState extends State<RoomToolForm> {
  final input = TextEditingController();
  String when = 'In 10 minutes';
  bool busy = false;
  String get tool => widget.tool;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (tool != 'Clean' && input.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      if (tool == 'Clean') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Clear room chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        await widget.onClear!();
      } else {
        await widget.onAnnounce!(
          '$tool · ${input.text.trim()}${tool == 'Gathering' ? ' · $when' : ''}',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room action could not be completed. Retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool == 'Vote'
                ? 'Start a vote'
                : tool == 'Video'
                    ? 'Watch together'
                    : tool == 'Calculator'
                        ? 'Gift calculator'
                        : tool == 'Prize'
                            ? 'Prize draw'
                            : tool == 'Wheel'
                                ? 'Room wheel'
                                : tool,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (tool == 'Broadcast')
            TextField(
              controller: input,
              maxLength: 100,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Message for the whole room',
              ),
            ),
          if (tool == 'Gathering') ...[
            TextField(
              controller: input,
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: 'In 10 minutes',
              items: [
                for (final t in ['In 10 minutes', 'In 30 minutes', 'In 1 hour'])
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (value) => when = value!,
            ),
          ],
          if (tool == 'Prize')
            const TextField(
              maxLength: 40,
              decoration: InputDecoration(
                hintText: 'Prize, for example 100K coins',
              ),
            ),
          if (tool == 'Video')
            const TextField(
              decoration: InputDecoration(hintText: 'Paste a video link'),
            ),
          if (tool == 'Vote')
            for (final label in [
              'Question',
              'Option 1',
              'Option 2',
              'Option 3 (optional)',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(decoration: InputDecoration(hintText: label)),
              ),
          if (tool == 'Mora') ...[
            ReferenceTabs(
              labels: const ['Rock', 'Paper', 'Scissors'],
              selected: -1,
              onSelected: (_) => showUiUnavailable(context, 'Mora'),
              pills: true,
            ),
            const EmptyContent('Choose one · scores unavailable'),
          ],
          if (tool == 'Calculator')
            const EmptyContent('Gift totals unavailable'),
          if (tool == 'Wheel')
            Container(
              height: 190,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xff8b2cf5),
                    Color(0xffec4899),
                    Color(0xfff59e0b),
                    Color(0xff22c55e),
                    Color(0xff8b2cf5),
                  ],
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xfffff7e0),
                child: Text('Go'),
              ),
            ),
          if (tool == 'Clean')
            const Text('Clear messages from the chatting area'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              onPressed: busy ||
                      !((tool == 'Broadcast' || tool == 'Gathering') &&
                              widget.onAnnounce != null ||
                          tool == 'Clean' && widget.onClear != null)
                  ? null
                  : submit,
              child: Text(
                busy
                    ? 'Sending…'
                    : {
                          'Broadcast': 'Send to room',
                          'Gathering': 'Announce',
                          'Prize': 'Draw a winner',
                          'Video': 'Play for the room',
                          'Vote': 'Start vote',
                          'Wheel': 'Spin',
                          'Calculator': 'Clear',
                          'Clean': 'Clear',
                        }[tool] ??
                        'Play',
              ),
            ),
          ),
        ],
      );
}

class TreasureSheet extends ConsumerStatefulWidget {
  const TreasureSheet({super.key});
  @override
  ConsumerState<TreasureSheet> createState() => _TreasureState();
}

class _TreasureState extends ConsumerState<TreasureSheet> {
  int world = 0, total = 0, quantity = 0, condition = 0;
  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(walletProvider).valueOrNull;
    final amounts = world == 0
        ? [10000, 50000, 100000, 200000]
        : [500000, 1000000, 5000000, 10000000];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                balance == null
                    ? 'Balance unavailable'
                    : '${balance.coins} coins',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const ReferenceArtwork('chest', 0, size: 72),
          ],
        ),
        ReferenceTabs(
          labels: const ['Room', 'World'],
          selected: world,
          onSelected: (i) => setState(() {
            world = i;
            total = 0;
            condition = 0;
          }),
          pills: true,
        ),
        _label('Total'),
        ReferenceTabs(
          labels: amounts.map(compactNumber).toList(),
          selected: total,
          onSelected: (i) => setState(() => total = i),
          pills: true,
        ),
        _label('Quantity'),
        ReferenceTabs(
          labels: const ['6', '10', '20', '30'],
          selected: quantity,
          onSelected: (i) => setState(() => quantity = i),
          pills: true,
        ),
        _label('Condition'),
        ReferenceTabs(
          labels: world == 0
              ? const ['All', 'Fans', 'On mic']
              : const ['All', 'Fans'],
          selected: condition,
          onSelected: (i) => setState(() => condition = i),
          pills: true,
        ),
        const SizedBox(height: 14),
        const SizedBox(
          width: double.infinity,
          child: GradientButton(
            onPressed: null,
            foreground: Color(0xff78350f),
            gradient: LinearGradient(
              colors: [Color(0xfffbbf24), Color(0xfff59e0b)],
            ),
            child: Text('Send'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text(
            'The undelivered golds will be refunded after 24 hours. Rule?',
            textAlign: TextAlign.center,
            style: TextStyle(color: NimzoStyle.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(
          text,
          style: const TextStyle(color: NimzoStyle.muted, fontSize: 12),
        ),
      );
}

class CrystalSheet extends StatelessWidget {
  const CrystalSheet({super.key, this.roomId});
  final String? roomId;
  @override
  Widget build(BuildContext context) => RoomDiamondSheet(roomId: roomId);
}

class VoiceEffectsSheet extends StatelessWidget {
  final bool micEnabled;
  final VoidCallback? onMic;
  const VoiceEffectsSheet({super.key, required this.micEnabled, this.onMic});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voice and Effect',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mic'),
            value: micEnabled,
            onChanged: onMic == null
                ? null
                : (_) {
                    Navigator.pop(context);
                    onMic!();
                  },
          ),
          for (final label in [
            'Noise Reduction',
            'Mount Effect',
            'Gift Effect',
            'Text',
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: true,
              onChanged: null,
            ),
        ],
      );
}

class RoomToolPage extends StatelessWidget {
  final String title;
  const RoomToolPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor:
            title == 'Music' ? Colors.white : const Color(0xff14052e),
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: title == 'Music'
              ? [
                  ReferenceCard(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: NimzoStyle.gradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            LucideIcons.music,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Nothing playing'),
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(value: 0),
                      ],
                    ),
                  ),
                  const EmptyContent('The audio library is unavailable.'),
                ]
              : [
                  const Center(
                    child: Text(
                      '—:—',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      NimzoAvatar(name: 'Room', size: 64),
                      Text(
                        'VS',
                        style: TextStyle(
                          color: Color(0xfffde68a),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      DashedCircle(size: 64, child: ReferenceIcon('mic')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(
                    value: .5,
                    color: Color(0xfffbbf24),
                    backgroundColor: Color(0xffec4899),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          onPressed: null,
                          child: Text('Support room'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: GradientButton(
                          onPressed: null,
                          child: Text('Support rival'),
                        ),
                      ),
                    ],
                  ),
                  const EmptyContent('PK is unavailable.'),
                ],
        ),
      );
}

class RoomProfilePage extends ConsumerStatefulWidget {
  final Room room;
  const RoomProfilePage({super.key, required this.room});
  @override
  ConsumerState<RoomProfilePage> createState() => _RoomProfileState();
}

class _RoomProfileState extends ConsumerState<RoomProfilePage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              ReferenceRoomAvatar(
                size: 44,
                url: widget.room.avatarPath == null
                    ? null
                    : ref
                        .read(supabaseProvider)
                        .storage
                        .from('room-images')
                        .getPublicUrl(widget.room.avatarPath!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'ID:${widget.room.roomNo}',
                      style: const TextStyle(
                          color: NimzoStyle.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ReferenceTabs(
              labels: const ['Profile', 'Member', 'Activity'],
              selected: tab,
              onSelected: (i) => setState(() => tab = i),
            ),
            if (tab == 0) ...[
              _detail('Announcement', widget.room.rules ?? 'Welcome'),
              _detail('Country', widget.room.country ?? '—'),
              Container(
                key: const ValueKey('room-real-stats'),
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xfff2f8f5),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xffdce9e1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Room information',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text('Lifetime gifts: ${widget.room.lifetimeGiftCoins} coins'),
                    const SizedBox(height: 5),
                    Text('Privacy: ${widget.room.isPrivate ? 'Private' : 'Public'}'),
                    const SizedBox(height: 5),
                    Text('Created: ${widget.room.createdAt.toLocal().toString().split(' ').first}'),
                    const SizedBox(height: 6),
                    AsyncContent(
                      value: ref.watch(roomMemberProfilesProvider(widget.room.id)),
                      onRetry: () => ref.invalidate(
                        roomMemberProfilesProvider(widget.room.id)),
                      builder: (members) => Text(
                        '${members.length} verified people in the room'),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      onPressed: () => context.push('/ranking'),
                      child: const Text('Top'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (ref.watch(currentUserIdProvider) == widget.room.ownerId)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                          context.push('/room/${widget.room.id}/settings'),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Room settings'),
                      ),
                    ),
                ],
              ),
            ] else if (tab == 1)
              AsyncContent(
                value: ref.watch(roomMemberProfilesProvider(widget.room.id)),
                onRetry: () =>
                    ref.invalidate(roomMemberProfilesProvider(widget.room.id)),
                builder: (members) => members.isEmpty
                    ? const EmptyContent('No members currently in this room')
                    : Column(
                        children: [
                          for (final p in members.values)
                            ListTile(
                              leading: NimzoAvatar(
                                name: p.displayName ?? 'N',
                                url: p.avatarPath == null
                                    ? null
                                    : ref
                                        .read(supabaseProvider)
                                        .storage
                                        .from('avatars')
                                        .getPublicUrl(p.avatarPath!),
                              ),
                              title: Text(
                                p.displayName ?? p.username ?? 'Nimzo user',
                              ),
                              onTap: () => context.push('/profile/${p.id}'),
                            ),
                        ],
                      ),
              )
            else
              _detail('Room created',
                widget.room.createdAt.toLocal().toString().split('.').first),
          ],
        ),
      );
  Widget _detail(String title, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: NimzoStyle.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(value),
          ],
        ),
      );
}
