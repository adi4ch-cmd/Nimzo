import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Nimzo', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            actions: [
              IconButton(icon: const Icon(Icons.emoji_events_outlined), onPressed: () => context.push('/discover')),
              IconButton(icon: const Icon(Icons.search), onPressed: () => context.go('/messages')),
            ],
            bottom: const TabBar(isScrollable: false, dividerHeight: 0, tabs: [Tab(text: 'Me'), Tab(text: 'Popular'), Tab(text: 'New Rooms')]),
          ),
          body: Column(children: [
            InkWell(
              onTap: () => context.push('/create-room'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(color: NimzoColors.primaryFaint, borderRadius: BorderRadius.circular(18), border: Border.all(color: NimzoColors.primaryLight)),
                child: const Row(children: [Icon(Icons.add_circle_outline, color: NimzoColors.primaryDark), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Create your room', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Start a live voice room and meet people', style: TextStyle(fontSize: 12, color: NimzoColors.secondary))])), Icon(Icons.chevron_right_rounded, color: NimzoColors.secondary)]),
              ),
            ),
            const Expanded(child: TabBarView(children: [_MeTab(), _PopularTab(), _NewTab()])),
          ]),
        ),
      );
}

class _MeTab extends ConsumerWidget {
  const _MeTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(myRoomsProvider).when(
        loading: () => const ShimmerView(rows: 4),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(myRoomsProvider)),
        data: (m) => (m['recent']!.isEmpty && m['followed']!.isEmpty)
            ? const EmptyView(title: 'No rooms yet', hint: 'Rooms you join or follow appear here.')
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                if (m['recent']!.isNotEmpty) ...[const Text('Recently joined'), const SizedBox(height: 8), ..._cards(context, m['recent']!)],
                if (m['followed']!.isNotEmpty) ...[const SizedBox(height: 16), const Text('Followed rooms'), const SizedBox(height: 8), ..._cards(context, m['followed']!)],
              ]),
      );
}

class _PopularTab extends ConsumerStatefulWidget {
  const _PopularTab();
  @override
  ConsumerState<_PopularTab> createState() => _P();
}

class _P extends ConsumerState<_PopularTab> {
  String? country = 'Pakistan';
  static const quick = ['Pakistan', 'India', 'Bangladesh', 'Saudi Arabia', 'Philippines'];
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final c in quick) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(c), selected: country == c, onSelected: (_) => setState(() => country = c))),
          ActionChip(label: const Text('More'), onPressed: () => showCountryPicker(context: context, onSelect: (c) => setState(() => country = c.name))),
        ])),
        Expanded(child: ref.watch(popularRoomsProvider(country)).when(
          loading: () => const ShimmerView(rows: 5),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(popularRoomsProvider(country))),
          data: (rooms) => rooms.isEmpty ? EmptyView(title: 'No rooms in ${country ?? 'this country'}') : RefreshIndicator(
            onRefresh: () async => ref.invalidate(popularRoomsProvider(country)),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              // Top 2 are highlighted; the rest follow in rank order (server orders by popularity).
              ..._cards(context, rooms.take(2).toList(), top: true),
              if (rooms.length > 2) ...[const SizedBox(height: 12), ..._cards(context, rooms.skip(2).toList())],
            ]),
          ),
        )),
      ]);
}

class _NewTab extends ConsumerWidget {
  const _NewTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(newRoomsProvider).when(
        loading: () => const ShimmerView(rows: 5),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(newRoomsProvider)),
        data: (rooms) => rooms.isEmpty ? const EmptyView(title: 'No new rooms', hint: 'Rooms created in the last 15 days show here.') : RefreshIndicator(
          onRefresh: () async => ref.invalidate(newRoomsProvider),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: _cards(context, rooms)),
        ),
      );
}

List<Widget> _cards(BuildContext c, List<Room> rooms, {bool top = false}) => [
      for (final r in rooms) Padding(padding: const EdgeInsets.only(bottom: 12), child: NimzoRoomCard(room: r, highlight: top, onTap: () => c.push('/room/${r.id}'))),
    ];

class NimzoRoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final bool highlight;
  const NimzoRoomCard({super.key, required this.room, required this.onTap, this.highlight = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: NimzoColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: highlight ? NimzoColors.gold : NimzoColors.border)),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: NimzoColors.primaryFaint, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.mic_none_rounded, color: NimzoColors.primaryDark)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('ID ${room.roomNo}  ·  ${room.country ?? 'Global'}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (room.isPrivate) const Icon(Icons.lock_outline, size: 18),
          ]),
        ),
      );
}
