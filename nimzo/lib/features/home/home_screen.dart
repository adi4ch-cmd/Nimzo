import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import '../../core/widgets/nimzo_icon.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nimzo',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        actions: [
          IconButton(
            icon: const NimzoIcon(
              Icons.emoji_events_outlined,
              color: NimzoColors.gold,
            ),
            onPressed: () => context.push('/discover'),
          ),
          IconButton(
            icon: const NimzoIcon(
              Icons.search_rounded,
              color: NimzoColors.primary,
            ),
            onPressed: () => context.go('/messages'),
          ),
        ],
        bottom: const TabBar(
          isScrollable: false,
          dividerHeight: 0,
          tabs: [
            Tab(text: 'Me'),
            Tab(text: 'Popular'),
            Tab(text: 'New Rooms'),
          ],
        ),
      ),
      body: Column(
        children: [
          InkWell(
            onTap: () => context.push('/create-room'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: NimzoColors.primaryFaint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NimzoColors.primaryLight),
              ),
              child: const Row(
                children: [
                  NimzoIcon(
                    Icons.add_circle_rounded,
                    color: NimzoColors.primaryDark,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your room',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Start a live voice room and meet people',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  NimzoIcon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(children: [_MeTab(), _PopularTab(), _NewTab()]),
          ),
        ],
      ),
    ),
  );
}

class _MeTab extends ConsumerWidget {
  const _MeTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(myRoomsProvider)
      .when(
        loading: () => const ShimmerView(rows: 4),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(myRoomsProvider),
        ),
        data: (m) => (m['recent']!.isEmpty && m['followed']!.isEmpty)
            ? const EmptyView(
                title: 'No rooms yet',
                hint: 'Rooms you join or follow appear here.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (m['recent']!.isNotEmpty) ...[
                    const Text('Recently joined'),
                    const SizedBox(height: 8),
                    ..._cards(context, m['recent']!),
                  ],
                  if (m['followed']!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Followed rooms'),
                    const SizedBox(height: 8),
                    ..._cards(context, m['followed']!),
                  ],
                ],
              ),
      );
}

class _PopularTab extends ConsumerStatefulWidget {
  const _PopularTab();
  @override
  ConsumerState<_PopularTab> createState() => _P();
}

class _P extends ConsumerState<_PopularTab> {
  String? country;
  static const quick = [
    'All',
    'Pakistan',
    'India',
    'Bangladesh',
    'Saudi Arabia',
    'Philippines',
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final c in quick)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NimzoIcon(
                        c == 'All' ? Icons.public_rounded : Icons.flag_rounded,
                        size: 17,
                        color: NimzoColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(c),
                    ],
                  ),
                  selected: (c == 'All' && country == null) || country == c,
                  onSelected: (_) =>
                      setState(() => country = c == 'All' ? null : c),
                ),
              ),
            ActionChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NimzoIcon(
                    Icons.public_rounded,
                    size: 17,
                    color: NimzoColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text('More'),
                ],
              ),
              onPressed: () => showCountryPicker(
                context: context,
                onSelect: (c) => setState(() => country = c.name),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ref
            .watch(popularRoomsProvider(country))
            .when(
              loading: () => const ShimmerView(rows: 5),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(popularRoomsProvider(country)),
              ),
              data: (rooms) => rooms.isEmpty
                  ? EmptyView(
                      title: country == null
                          ? 'No popular rooms'
                          : 'No rooms in $country',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(popularRoomsProvider(country)),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          // Top 2 are highlighted; the rest follow in rank order (server orders by popularity).
                          ..._cards(context, rooms.take(2).toList(), top: true),
                          if (rooms.length > 2) ...[
                            const SizedBox(height: 12),
                            ..._cards(context, rooms.skip(2).toList()),
                          ],
                        ],
                      ),
                    ),
            ),
      ),
    ],
  );
}

class _NewTab extends ConsumerWidget {
  const _NewTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(newRoomsProvider)
      .when(
        loading: () => const ShimmerView(rows: 5),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(newRoomsProvider),
        ),
        data: (rooms) => rooms.isEmpty
            ? const EmptyView(
                title: 'No new rooms',
                hint: 'Rooms created in the last 15 days show here.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(newRoomsProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _cards(context, rooms),
                ),
              ),
      );
}

List<Widget> _cards(BuildContext c, List<Room> rooms, {bool top = false}) => [
  for (final r in rooms)
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NimzoRoomCard(
        room: r,
        highlight: top,
        onTap: () => c.push('/room/${r.id}'),
      ),
    ),
];

class NimzoRoomCard extends ConsumerWidget {
  final Room room;
  final VoidCallback onTap;
  final bool highlight;
  const NimzoRoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: NimzoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NimzoColors.border),
      ),
      child: Row(
        children: [
          _RoomImage(
            url: storageUrl(
              ref.watch(supabaseProvider),
              'room-images',
              room.avatarPath,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Room ${room.roomNo}  ·  ${room.country ?? 'Global'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NimzoIcon(
            room.isPrivate ? Icons.lock_rounded : Icons.chevron_right_rounded,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

class _RoomImage extends StatelessWidget {
  final String? url;
  const _RoomImage({this.url});
  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: NimzoColors.primaryFaint,
      child: Center(
        child: NimzoIcon(
          Icons.mic_rounded,
          color: NimzoColors.primaryDark,
          size: 24,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 60,
        height: 60,
        child: url == null
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
