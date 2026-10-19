import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../events/events_screen.dart';
import 'home_header.dart';
import '../rooms/domain/room.dart';
import '../rooms/presentation/room_controller.dart';

/// Maintained for existing NIMZO room tests and 'my room' dependents.
final ownedRoomPreviewProvider = FutureProvider<Room?>((ref) async {
  final repo = ref.watch(roomRepositoryProvider);
  final id = await repo.ownedRoomId();
  return id == null ? null : repo.get(id);
});

/// Historical rooms may store either an ISO country code or a country name.
/// Do not silently drop real followed/new rooms when formats differ.
bool roomCountryMatches(
    String? stored, String? selectedCode, String selectedName) {
  if (selectedCode == null) return true;
  final value = stored?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value == selectedCode.trim().toLowerCase() ||
      value == selectedName.trim().toLowerCase();
}

/// Room directory with the supplied My/Popular/Discover/New/Pakistan layout.
/// Every card is backed by a real NIMZO room; no stock rooms or fake counts.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int tab;
  String? country;
  String countryName = 'All';
  bool opening = false;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      tab = widget.initialTab.clamp(0, 4);
    }
  }

  RoomCountrySelection? get selectedCountry => tab == 4
      ? (code: 'PK', name: 'Pakistan')
      : country == null
          ? null
          : (code: country!, name: countryName);

  void selectTab(int index) {
    setState(() => tab = index);
    // Keep the retained branch URL aligned with the visible tab, so the Events
    // header can reopen My after a local switch to Discover.
    GoRouter.maybeOf(context)?.go('/home?tab=$index');
  }

  Future<void> openMine() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final id = await ref.read(roomRepositoryProvider).ownedRoomId();
      if (mounted)
        context.push(
          id == null ? '/create-room' : '/room/' + id,
        );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open room. Retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  void selectCountry() {
    var searchText = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          final filtered = CountryService()
              .getAll()
              .where(
                (c) =>
                    c.name.toLowerCase().contains(searchText.toLowerCase()) ||
                    c.countryCode
                        .toLowerCase()
                        .contains(searchText.toLowerCase()),
              )
              .take(70)
              .toList();
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .70,
              child: Column(children: [
                const SizedBox(height: 11),
                Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xffc7bfe0),
                        borderRadius: BorderRadius.circular(5))),
                Row(children: [
                  const Spacer(),
                  const Text('Apply Filter',
                      style: TextStyle(
                          color: Color(0xff23182f),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close country filter',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  )),
                ]),
                const Divider(height: 1, color: Color(0xfff0edf8)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Country',
                        style: TextStyle(
                            color: Color(0xff17111d),
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    key: const ValueKey('room-country-search'),
                    onChanged: (value) => updateSheet(() => searchText = value),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      filled: true,
                      fillColor: const Color(0xfff6f5fb),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xffb2aaca)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                    child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  children: [
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      ChoiceChip(
                        key: const ValueKey('room-country-all'),
                        label: const Text('All'),
                        selected: country == null,
                        showCheckmark: false,
                        selectedColor: NimzoStyle.primary,
                        backgroundColor: const Color(0xfff2eeff),
                        labelStyle: TextStyle(
                          color: country == null
                              ? Colors.white
                              : const Color(0xff726290),
                        ),
                        onSelected: (_) {
                          setState(() {
                            country = null;
                            countryName = 'All';
                          });
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      for (final c in filtered)
                        ChoiceChip(
                          key: ValueKey('room-country-${c.countryCode}'),
                          label: Text('${c.flagEmoji} ${c.name}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: country == c.countryCode,
                          showCheckmark: false,
                          backgroundColor: const Color(0xfff2eeff),
                          selectedColor: const Color(0xffe4d2ff),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                              color: Color(0xff6f6289), fontSize: 12),
                          onSelected: (_) {
                            setState(() {
                              country = c.countryCode;
                              countryName = c.name;
                            });
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ]),
                  ],
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = HomeHeader(
      selected: tab,
      onSelected: selectTab,
      onSearch: () => context.push('/discover'),
    );
    if (tab == 2) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(children: [
          header,
          const Expanded(child: EventBannerList()),
        ]),
      );
    }

    AsyncValue<List<Room>> data;
    if (tab == 3) {
      data = ref.watch(newRoomsProvider);
    } else if (tab == 0) {
      data = ref.watch(myRoomsProvider).whenData((value) {
        // Show recent and followed rooms once when a room belongs to both.
        return {
          for (final room in [
            ...value['recent'] ?? <Room>[],
            ...value['followed'] ?? <Room>[],
          ])
            room.id: room,
        }.values.toList();
      });
    } else {
      data = ref.watch(popularRoomsProvider(selectedCountry));
    }
    if (country != null && (tab == 0 || tab == 3)) {
      data = data.whenData((rooms) => rooms
          .where(
            (room) => roomCountryMatches(room.country, country, countryName),
          )
          .toList());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        header,
        if (tab != 4)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            child: Row(children: [
              ActionChip(
                key: const ValueKey('home-country-all'),
                label: const Text('All'),
                onPressed: () => setState(() {
                  country = null;
                  countryName = 'All';
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(country == null ? 'All countries' : countryName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Filter by country',
                onPressed: selectCountry,
                icon: const Icon(Icons.filter_list, color: NimzoStyle.primary),
              ),
              IconButton(
                tooltip: 'Rankings',
                onPressed: () => context.push('/ranking'),
                icon: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xffffc547)),
              ),
            ]),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (tab == 3) {
                ref.invalidate(newRoomsProvider);
                await ref.read(newRoomsProvider.future);
              } else if (tab == 0) {
                ref.invalidate(myRoomsProvider);
                await ref.read(myRoomsProvider.future);
              } else {
                ref.invalidate(popularRoomsProvider(selectedCountry));
                await ref.read(popularRoomsProvider(selectedCountry).future);
              }
            },
            child: CustomScrollView(
              key: PageStorageKey('home-rooms-$tab'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                data.when(
                  loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator())),
                  error: (error, _) => SliverFillRemaining(
                    child: Center(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Rooms could not be loaded.'),
                        TextButton(
                            onPressed: () {
                              ref.invalidate(
                                  popularRoomsProvider(selectedCountry));
                              ref.invalidate(myRoomsProvider);
                              ref.invalidate(newRoomsProvider);
                            },
                            child: const Text('Retry')),
                      ],
                    )),
                  ),
                  data: (rooms) => rooms.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(child: Text('No rooms found.')))
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: .81,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _LiveCard(room: rooms[i]),
                              childCount: rooms.length,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        elevation: 0,
        backgroundColor: const Color(0xffff4e91),
        foregroundColor: Colors.white,
        onPressed: opening ? null : openMine,
        icon: const Icon(Icons.mic_rounded),
        label: Text(opening ? 'Opening...' : 'Go Live'),
      ),
    );
  }
}

class _LiveCard extends ConsumerWidget {
  final Room room;
  const _LiveCard({required this.room});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = room.avatarPath;
    final url = path == null
        ? null
        : ref
            .read(supabaseProvider)
            .storage
            .from('room-images')
            .getPublicUrl(path);
    return InkWell(
      onTap: () => context.push('/room/' + room.id),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff9b501a),
              Color(0xffffd680),
              Color(0xff9d641c),
              Color(0xffeac061),
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [
            BoxShadow(color: Color(0x3773460b), blurRadius: 5),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(fit: StackFit.expand, children: [
            if (url != null)
              Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _MissingAvatar())
            else
              const _MissingAvatar(),
            const DecoratedBox(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Colors.transparent,
                  Color(0xcf000000),
                ],
                stops: [0, .45, 1],
              ),
            )),
            Positioned(
              top: 10,
              left: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🎙 Audio Live',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
            Positioned(
              left: 9,
              right: 6,
              bottom: 9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('ID: ' + room.roomNo.toString(),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MissingAvatar extends StatelessWidget {
  const _MissingAvatar();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff533a71), Color(0xff1e2455)],
          ),
        ),
        child: Center(
            child: Icon(Icons.mic_rounded, size: 59, color: Color(0xffe9c776))),
      );
}
