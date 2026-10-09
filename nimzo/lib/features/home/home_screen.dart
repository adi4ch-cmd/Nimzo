import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../rooms/domain/room.dart';
import '../rooms/data/room_chat_repository.dart';
import '../rooms/presentation/room_controller.dart';

final ownedRoomPreviewProvider = FutureProvider<Room?>((ref) async {
  final repo = ref.watch(roomRepositoryProvider);
  final id = await repo.ownedRoomId();
  return id == null ? null : repo.get(id);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? country;
  String countryName = 'All countries';
  int tab = 0;
  bool opening = false;

  Future<void> openMine() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final id = await ref.read(roomRepositoryProvider).ownedRoomId();
      if (mounted) context.push(id == null ? '/create-room' : '/room/$id');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open your room. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(ownedRoomPreviewProvider).valueOrNull;
    final popular = ref.watch(popularRoomsProvider(country));
    final mine = tab == 0 ? null : ref.watch(myRoomsProvider);
    final AsyncValue<List<Room>> rooms = tab == 0
        ? popular
        : mine!.whenData((m) => m[tab == 1 ? 'followed' : 'recent'] ?? []);
    void retry() {
      ref.invalidate(popularRoomsProvider(country));
      ref.invalidate(myRoomsProvider);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          retry();
          if (tab == 0) {
            await ref.read(popularRoomsProvider(country).future);
          } else {
            await ref.read(myRoomsProvider.future);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(child: GradientText('NIMZO')),
                  IconButton(
                    tooltip: 'Search',
                    icon: const ReferenceIcon('search', size: 22),
                    onPressed: () => context.push('/discover'),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const ReferenceIcon('bell', size: 22),
                    onPressed: () => context.push('/notifications'),
                  ),
                  ActionChip(
                    label: SizedBox(
                        width: 72,
                        child: Text('$countryName ▾',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12))),
                    onPressed: () => showCountryPicker(
                      context: context,
                      onSelect: (c) => setState(() {
                        country = c.countryCode;
                        countryName = c.name;
                      }),
                      favorite: const ['PK', 'SA', 'IN'],
                      countryListTheme: const CountryListThemeData(
                        bottomSheetHeight: 500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xfff3e8ff), Color(0xfffde7f3)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        ReferenceRoomAvatar(
                            url: owned?.avatarPath == null
                                ? null
                                : ref
                                    .read(supabaseProvider)
                                    .storage
                                    .from('room-images')
                                    .getPublicUrl(owned!.avatarPath!)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                owned?.name ?? 'My room',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const Text(
                                'One account, one room',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NimzoStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GradientButton(
                          onPressed: opening ? null : openMine,
                          child: Text(opening ? 'Opening…' : 'Open my room'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ReferenceTabs(
                      labels: const ['Popular', 'Followed', 'Recent'],
                      selected: tab,
                      onSelected: (i) => setState(() => tab = i)),
                  const SizedBox(height: 6),
                  AsyncContent(
                    value: rooms,
                    onRetry: retry,
                    builder: (list) => list.isEmpty
                        ? const EmptyContent('No rooms available yet.')
                        : Column(
                            children: [
                              for (final room in list) RoomTile(room: room),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomTile extends ConsumerWidget {
  final Room room;
  const RoomTile({super.key, required this.room});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = room.avatarPath;
    final url = path == null
        ? null
        : ref
            .watch(supabaseProvider)
            .storage
            .from('room-images')
            .getPublicUrl(path);
    return InkWell(
      onTap: () => context.push('/room/${room.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: NimzoStyle.line)),
        ),
        child: Row(
          children: [
            ReferenceRoomAvatar(url: url),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ID:${room.roomNo} · ${ref.watch(onlineCountProvider(room.id)).valueOrNull?.toString() ?? '—'} online',
                    style: const TextStyle(
                      color: NimzoStyle.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              compactNumber(room.lifetimeGiftCoins),
              style: const TextStyle(
                color: Color(0xffdb2777),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
