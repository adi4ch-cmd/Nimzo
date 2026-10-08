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
  'Clean'
];

Future<void> showPartyTools(BuildContext context) async {
  final tool = await showReferenceSheet<int>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Party Tools',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .9,
            children: [
              for (var i = 0; i < roomToolNames.length; i++)
                InkWell(
                    onTap: () => Navigator.pop(context, i),
                    child: Column(children: [
                      ReferenceArtwork('tool', i, size: 48),
                      const SizedBox(height: 4),
                      Text(roomToolNames[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11))
                    ]))
            ])
      ]));
  if (tool == null || !context.mounted) return;
  if (tool == 6) {
    await showReferenceSheet(context, const TreasureSheet());
    return;
  }
  if (tool == 2 || tool == 3 || tool == 10) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RoomToolPage(title: roomToolNames[tool])));
    return;
  }
  await showReferenceSheet(context, RoomToolForm(tool: roomToolNames[tool]));
}

class RoomToolForm extends StatelessWidget {
  final String tool;
  const RoomToolForm({super.key, required this.tool});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        if (tool == 'Broadcast')
          const TextField(
              maxLength: 100,
              maxLines: 3,
              decoration:
                  InputDecoration(hintText: 'Message for the whole room')),
        if (tool == 'Gathering') ...[
          const TextField(
              maxLength: 40, decoration: InputDecoration(hintText: 'Title')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              initialValue: 'In 10 minutes',
              items: [
                for (final t in ['In 10 minutes', 'In 30 minutes', 'In 1 hour'])
                  DropdownMenuItem(value: t, child: Text(t))
              ],
              onChanged: (_) {})
        ],
        if (tool == 'Prize')
          const TextField(
              maxLength: 40,
              decoration:
                  InputDecoration(hintText: 'Prize, for example 100K coins')),
        if (tool == 'Video')
          const TextField(
              decoration: InputDecoration(hintText: 'Paste a video link')),
        if (tool == 'Vote')
          for (final label in [
            'Question',
            'Option 1',
            'Option 2',
            'Option 3 (optional)'
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(decoration: InputDecoration(hintText: label))),
        if (tool == 'Mora') ...[
          ReferenceTabs(
              labels: const ['Rock', 'Paper', 'Scissors'],
              selected: -1,
              onSelected: (_) => showUiUnavailable(context, 'Mora'),
              pills: true),
          const EmptyContent('Choose one · scores unavailable')
        ],
        if (tool == 'Calculator') const EmptyContent('Gift totals unavailable'),
        if (tool == 'Wheel')
          Container(
              height: 190,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    Color(0xff8b2cf5),
                    Color(0xffec4899),
                    Color(0xfff59e0b),
                    Color(0xff22c55e),
                    Color(0xff8b2cf5)
                  ])),
              child: const CircleAvatar(
                  backgroundColor: Color(0xfffff7e0), child: Text('Go'))),
        if (tool == 'Clean')
          const Text('Clear messages from the chatting area'),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: GradientButton(
                onPressed: null,
                child: Text({
                      'Broadcast': 'Send to room',
                      'Gathering': 'Announce',
                      'Prize': 'Draw a winner',
                      'Video': 'Play for the room',
                      'Vote': 'Start vote',
                      'Wheel': 'Spin',
                      'Calculator': 'Clear',
                      'Clean': 'Clear'
                    }[tool] ??
                    'Play'))),
      ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                balance == null
                    ? 'Balance unavailable'
                    : '${balance.coins} coins',
                style: const TextStyle(fontWeight: FontWeight.w700))),
        const ReferenceArtwork('chest', 0, size: 72)
      ]),
      ReferenceTabs(
          labels: const ['Room', 'World'],
          selected: world,
          onSelected: (i) => setState(() {
                world = i;
                total = 0;
                condition = 0;
              }),
          pills: true),
      _label('Total'),
      ReferenceTabs(
          labels: amounts.map(compactNumber).toList(),
          selected: total,
          onSelected: (i) => setState(() => total = i),
          pills: true),
      _label('Quantity'),
      ReferenceTabs(
          labels: const ['6', '10', '20', '30'],
          selected: quantity,
          onSelected: (i) => setState(() => quantity = i),
          pills: true),
      _label('Condition'),
      ReferenceTabs(
          labels: world == 0
              ? const ['All', 'Fans', 'On mic']
              : const ['All', 'Fans'],
          selected: condition,
          onSelected: (i) => setState(() => condition = i),
          pills: true),
      const SizedBox(height: 14),
      const SizedBox(
          width: double.infinity,
          child: GradientButton(
              onPressed: null,
              foreground: Color(0xff78350f),
              gradient: LinearGradient(
                  colors: [Color(0xfffbbf24), Color(0xfff59e0b)]),
              child: Text('Send'))),
      const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text(
              'The undelivered golds will be refunded after 24 hours. Rule?',
              textAlign: TextAlign.center,
              style: TextStyle(color: NimzoStyle.muted, fontSize: 12))),
    ]);
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Text(text,
          style: const TextStyle(color: NimzoStyle.muted, fontSize: 12)));
}

class CrystalSheet extends StatelessWidget {
  const CrystalSheet({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        const ReferenceArtwork('crys', 0, size: 96),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0)
              const Icon(Icons.chevron_right,
                  color: NimzoStyle.primary, size: 14),
            ReferenceArtwork('gem', i, size: 38)
          ]
        ]),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Send gifts to boom the crystal!',
                style: TextStyle(
                    color: NimzoStyle.primary, fontWeight: FontWeight.w700))),
        const LinearProgressIndicator(
            value: 0,
            color: NimzoStyle.primary,
            backgroundColor: NimzoStyle.line),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(
              flex: 2,
              child: Column(children: [
                ReferenceArtwork('prz', 0, size: 84),
                Text('TOP1 Only',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
              ])),
          for (var i = 1; i < 5; i++)
            Expanded(child: ReferenceArtwork('prz', i, size: 48))
        ]),
        const EmptyContent(
            'Progress and prizes unavailable. Restart everyday at 11:00 p.m (GMT+3)'),
      ]);
}

class VoiceEffectsSheet extends StatelessWidget {
  final bool micEnabled;
  final VoidCallback? onMic;
  const VoiceEffectsSheet({super.key, required this.micEnabled, this.onMic});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Voice and Effect',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mic'),
            value: micEnabled,
            onChanged: onMic == null
                ? null
                : (_) {
                    Navigator.pop(context);
                    onMic!();
                  }),
        for (final label in [
          'Noise Reduction',
          'Mount Effect',
          'Gift Effect',
          'Text'
        ])
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: true,
              onChanged: null),
      ]);
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
                      child: Column(children: [
                    Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                            gradient: NimzoStyle.gradient,
                            borderRadius: BorderRadius.circular(22)),
                        child: const Icon(LucideIcons.music,
                            color: Colors.white, size: 34)),
                    const SizedBox(height: 10),
                    const Text('Nothing playing'),
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(value: 0)
                  ])),
                  const EmptyContent('The audio library is unavailable.'),
                ]
              : [
                  const Center(
                      child: Text('—:—',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(height: 14),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        NimzoAvatar(name: 'Room', size: 64),
                        Text('VS',
                            style: TextStyle(
                                color: Color(0xfffde68a),
                                fontSize: 28,
                                fontWeight: FontWeight.w700)),
                        DashedCircle(size: 64, child: Icon(LucideIcons.mic))
                      ]),
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(
                      value: .5,
                      color: Color(0xfffbbf24),
                      backgroundColor: Color(0xffec4899)),
                  const SizedBox(height: 20),
                  const Row(children: [
                    Expanded(
                        child: GradientButton(
                            onPressed: null, child: Text('Support room'))),
                    SizedBox(width: 10),
                    Expanded(
                        child: GradientButton(
                            onPressed: null, child: Text('Support rival')))
                  ]),
                  const EmptyContent('PK is unavailable.'),
                ]));
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
      appBar: AppBar(title: Text(widget.room.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('ID:${widget.room.roomNo}',
            style: const TextStyle(color: NimzoStyle.muted, fontSize: 12)),
        const SizedBox(height: 12),
        ReferenceTabs(
            labels: const ['Profile', 'Member', 'Activity'],
            selected: tab,
            onSelected: (i) => setState(() => tab = i)),
        if (tab == 0) ...[
          _row('Announcement', widget.room.rules ?? 'Welcome'),
          _row('Country', widget.room.country ?? '—'),
          for (final label in [
            'Room Rewards',
            'Room Support',
            'Room Certification',
            'Room Activity',
            'Apply for Banner'
          ])
            _row(label, '›'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Room Medal',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const Row(children: [
            ReferenceArtwork('rmed', 0, size: 80),
            SizedBox(width: 10),
            ReferenceArtwork('rmed', 1, size: 80)
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: GradientButton(
                    onPressed: () => context.push('/ranking'),
                    child: const Text('Top'))),
            const SizedBox(width: 10),
            Expanded(
                child: GradientButton(
                    onPressed: () =>
                        context.push('/room/${widget.room.id}/settings'),
                    child: const Text('Setting')))
          ]),
        ] else if (tab == 1)
          AsyncContent(
            value: ref.watch(roomSeatProfilesProvider(widget.room.id)),
            onRetry: () =>
                ref.invalidate(roomSeatProfilesProvider(widget.room.id)),
            builder: (members) => members.isEmpty
                ? const EmptyContent('Nobody on mic')
                : Column(children: [
                    for (final p in members.values)
                      ListTile(
                          leading: NimzoAvatar(name: p.displayName ?? 'N'),
                          title:
                              Text(p.displayName ?? p.username ?? 'Nimzo user'),
                          onTap: () => context.push('/profile/${p.id}'))
                  ]),
          )
        else
          const EmptyContent('No activity yet'),
      ]));
  Widget _row(String title, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: NimzoStyle.line))),
      child: Row(children: [
        Expanded(child: Text(title)),
        Text(value, style: const TextStyle(color: NimzoStyle.muted))
      ]));
}
