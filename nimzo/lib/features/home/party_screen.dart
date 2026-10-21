import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tingle_surface.dart';
import '../games/games_catalog_screen.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

/// Presentation-only directory. Room, follow and game contracts stay unchanged.
class PartyScreen extends ConsumerStatefulWidget {
  const PartyScreen({super.key});

  @override
  ConsumerState<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<PartyScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final rooms = tab == 1
        ? ref
            .watch(myRoomsProvider)
            .whenData((value) => value['followed'] ?? <Room>[])
        : ref.watch(popularRoomsProvider(null));
    return Scaffold(
      body: DecoratedBox(
          decoration: const BoxDecoration(gradient: tingleSky),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
                child: Row(children: [
                  Expanded(
                      child: TingleTabs(
                          labels: const ['Party', 'Follow', 'Games'],
                          selected: tab,
                          light: true,
                          onSelected: (value) => setState(() => tab = value))),
                  IconButton(
                      tooltip: 'Search rooms',
                      onPressed: () => context.push('/discover'),
                      icon: const Icon(Icons.search_rounded,
                          size: 22, color: Colors.white)),
                  IconButton(
                      tooltip: 'Rankings',
                      onPressed: () => context.push('/ranking'),
                      icon: const Icon(Icons.emoji_events_rounded,
                          size: 22, color: Color(0xffffca50))),
                ])),
            if (tab != 2)
              const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                          label: Text('All',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: NimzoStyle.primary,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact))),
            Expanded(
                child: tab == 2
                    ? const GamesCatalogScreen()
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (tab == 1) {
                            ref.invalidate(myRoomsProvider);
                            await ref.read(myRoomsProvider.future);
                          } else {
                            ref.invalidate(popularRoomsProvider(null));
                            await ref.read(popularRoomsProvider(null).future);
                          }
                        },
                        child: rooms.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, __) => ListView(children: [
                            const SizedBox(height: 80),
                            const Center(
                                child: Text('Rooms could not be loaded.')),
                            TextButton(
                                onPressed: () {
                                  ref.invalidate(myRoomsProvider);
                                  ref.invalidate(popularRoomsProvider(null));
                                },
                                child: const Text('Retry')),
                          ]),
                          data: (items) => ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                              itemCount: items.isEmpty ? 1 : items.length,
                              itemBuilder: (context, index) {
                                if (items.isEmpty)
                                  return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 80),
                                      child: Center(
                                          child: Text(tab == 1
                                              ? 'No followed rooms yet'
                                              : 'No parties live right now')));
                                final room = items[index];
                                final avatar = room.avatarPath == null
                                    ? null
                                    : ref
                                        .read(supabaseProvider)
                                        .storage
                                        .from('room-images')
                                        .getPublicUrl(room.avatarPath!);
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Material(
                                        color: index.isEven
                                            ? const Color(0xffffdafa)
                                            : const Color(0xffffe1e2),
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            key: ValueKey(
                                                'party-room-${room.id}'),
                                            onTap: () => context
                                                .push('/room/${room.id}'),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Row(children: [
                                                  ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              9),
                                                      child: SizedBox(
                                                          width: 54,
                                                          height: 54,
                                                          child: avatar == null
                                                              ? const ColoredBox(
                                                                  color: Color(
                                                                      0xffb884d9),
                                                                  child: Icon(
                                                                      Icons
                                                                          .mic_rounded,
                                                                      color: Colors
                                                                          .white))
                                                              : Image.network(
                                                                  avatar,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (_,
                                                                          __,
                                                                          ___) =>
                                                                      const Icon(Icons.mic_rounded)))),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(room.name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                        const SizedBox(
                                                            height: 5),
                                                        Text(
                                                            room.country ??
                                                                'Audio room',
                                                            style: const TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                    0xffa478ac))),
                                                      ])),
                                                  const Icon(
                                                      Icons.graphic_eq_rounded,
                                                      size: 20,
                                                      color: Color(0xffbc7ac4)),
                                                ])))));
                              }),
                        ))),
          ])),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              elevation: 0,
              backgroundColor: const Color(0xffff4e91),
              foregroundColor: Colors.white,
              onPressed: () => context.push('/create-room'),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Party')),
    );
  }
}
