import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/reference_widgets.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

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
          await ref.read(popularRoomsProvider(country).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'NIMZO',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: NimzoStyle.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(LucideIcons.search, size: 22),
                    onPressed: () => context.push('/discover'),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(LucideIcons.bell, size: 22),
                    onPressed: () => context.push('/notifications'),
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create your room',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'One account, one room',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NimzoStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: opening ? null : openMine,
                          child: Text(opening ? 'Opening…' : 'Open my room'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ActionChip(
                      label: Text(countryName),
                      avatar: const Icon(LucideIcons.globe, size: 16),
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
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                            child: TextButton(
                          onPressed: () => setState(() => tab = i),
                          child: Text(
                            ['Popular', 'Followed', 'Recent'][i],
                            style: TextStyle(
                              color:
                                  tab == i ? NimzoStyle.ink : NimzoStyle.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                    ],
                  ),
                  const Divider(height: 1),
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
            NimzoAvatar(name: room.name, url: url),
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
                    'ID:${room.roomNo}',
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
