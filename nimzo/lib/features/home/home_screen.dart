import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
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
bool roomCountryMatches(String? stored, String? selectedCode, String selectedName) {
  if (selectedCode == null) return true;
  final value = stored?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value == selectedCode.trim().toLowerCase() ||
      value == selectedName.trim().toLowerCase();
}

/// Explore/New/Follow live-room screen derived from the supplied Tingle layout.
/// Every card is backed by a real NIMZO room; no stock rooms or fake counts.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int tab = 0;
  String? country;
  String countryName = 'All';
  bool opening = false;

  RoomCountrySelection? get selectedCountry =>
      country == null ? null : (code: country!, name: countryName);

  void selectTab(int i) {
    if (i == 2) {
      context.push('/pk');
      return;
    }
    setState(() => tab = i);
  }

  Future<void> openMine() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final id = await ref.read(roomRepositoryProvider).ownedRoomId();
      if (mounted) context.push(
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
          final filtered = CountryService().getAll().where((c) =>
            c.name.toLowerCase().contains(searchText.toLowerCase()) ||
            c.countryCode.toLowerCase().contains(searchText.toLowerCase()),
          ).take(70).toList();
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .70,
              child: Column(children: [
                const SizedBox(height: 11),
                Container(width: 32, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffc7bfe0),
                    borderRadius: BorderRadius.circular(5))),
                Row(children: [
                  const Spacer(),
                  const Text('Apply Filter',
                    style: TextStyle(
                      color: Color(0xff23182f),
                      fontSize: 20, fontWeight: FontWeight.w800)),
                  Expanded(child: Align(
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
                        fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    key: const ValueKey('room-country-search'),
                    onChanged: (value) =>
                      updateSheet(() => searchText = value),
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
                Expanded(child: ListView(
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
                            ? Colors.white : const Color(0xff726290),
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
    AsyncValue<List<Room>> data;
    if (tab == 1) {
      data = ref.watch(newRoomsProvider);
    } else if (tab == 3) {
      data = ref.watch(myRoomsProvider).whenData(
        (m) => m['followed'] ?? const <Room>[],
      );
    } else {
      data = ref.watch(popularRoomsProvider(selectedCountry));
    }
    if (country != null && tab != 0) {
      data = data.whenData(
        (rooms) => rooms.where(
          (r) => roomCountryMatches(r.country, country, countryName),
        ).toList(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f4ff),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularRoomsProvider(selectedCountry));
          ref.invalidate(newRoomsProvider);
          ref.invalidate(myRoomsProvider);
          if (tab == 1) {
            await ref.read(newRoomsProvider.future);
          } else if (tab == 3) {
            await ref.read(myRoomsProvider.future);
          } else {
            await ref.read(popularRoomsProvider(selectedCountry).future);
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff283e6d), Color(0xff2068a5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 26, 18, 14),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (var i = 0; i < 4; i++)
                          InkWell(
                            key: ValueKey('explore-tab-$i'),
                            onTap: () => selectTab(i),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 17, bottom: 14),
                              child: Text(
                                const ['Explore', 'New', 'PK', 'Follow'][i],
                                style: TextStyle(
                                  color: tab == i
                                    ? Colors.white : Colors.white54,
                                  fontSize: i == 0 ? 22 : 16,
                                  fontWeight: tab == i
                                    ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search rooms and users',
                    onPressed: () => context.push('/discover'),
                    icon: const Icon(Icons.search_rounded,
                      color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Rankings',
                    onPressed: () => context.push('/ranking'),
                    icon: const Icon(Icons.emoji_events_rounded,
                      color: Color(0xffffc547)),
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CountryChip(
                        label: countryName, onTap: selectCountry,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  ActionChip(
                    label: const Text('All'),
                    avatar: const Icon(Icons.public, size: 16),
                    backgroundColor: NimzoStyle.primary,
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide.none,
                    onPressed: () => setState(() {
                      country = null;
                      countryName = 'All';
                    }),
                  ),
                  IconButton(
                    tooltip: 'Filter by country',
                    onPressed: selectCountry,
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                  ),
                ]),
              ]),
            )),
            data.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
              error: (error, _) => SliverFillRemaining(
                child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rooms could not be loaded.'),
                    TextButton(onPressed: () {
                      ref.invalidate(popularRoomsProvider(selectedCountry));
                      ref.invalidate(myRoomsProvider);
                      ref.invalidate(newRoomsProvider);
                    }, child: const Text('Retry')),
                  ],
                )),
              ),
              data: (rooms) => rooms.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('No rooms found.')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(15, 18, 15, 105),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .76,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xfff34c94),
        foregroundColor: Colors.white,
        onPressed: opening ? null : openMine,
        icon: const Icon(Icons.videocam_off_rounded),
        label: Text(opening ? 'Opening...' : 'Go Audio Live'),
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CountryChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.public, size: 16, color: Colors.white),
        const SizedBox(width: 5),
        Flexible(child: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white))),
        const Icon(Icons.expand_more, color: Colors.white),
      ]),
    ),
  );
}

class _LiveCard extends ConsumerWidget {
  final Room room;
  const _LiveCard({required this.room});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = room.avatarPath;
    final url = path == null ? null : ref.read(supabaseProvider)
        .storage.from('room-images').getPublicUrl(path);
    return InkWell(
      onTap: () => context.push('/room/' + room.id),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff9b501a), Color(0xffffd680),
              Color(0xff9d641c), Color(0xffeac061),
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
              Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const _MissingAvatar())
            else
              const _MissingAvatar(),
            const DecoratedBox(decoration: BoxDecoration(
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
              top: 10, left: 7,
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
              left: 9, right: 6, bottom: 9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('ID: ' + room.roomNo.toString(),
                    style: const TextStyle(
                      fontSize: 10, color: Colors.white70)),
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
    child: Center(child: Icon(Icons.mic_rounded,
      size: 59, color: Color(0xffe9c776))),
  );
}
