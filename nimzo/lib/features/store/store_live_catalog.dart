import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';

/// The live Store uses ORIGINAL NIMZO vector art. The third-party APK
/// animations are for research/preview only and are not distributed here.
class NimzoCosmeticItem {
  const NimzoCosmeticItem({
    required this.id,
    required this.category,
    required this.name,
    required this.variant,
    required this.coinPrice,
  });

  final String id;
  final String category;
  final String name;
  final int variant;
  final int coinPrice;

  factory NimzoCosmeticItem.fromJson(Map<String, dynamic> json) =>
      NimzoCosmeticItem(
        id: json['id'] as String,
        category: json['category'] as String,
        name: json['name'] as String,
        variant: (json['variant'] as num).toInt(),
        coinPrice: (json['coin_price'] as num).toInt(),
      );
}

class NimzoStoreSnapshot {
  const NimzoStoreSnapshot({
    required this.items,
    required this.owned,
    required this.equipped,
  });

  final List<NimzoCosmeticItem> items;
  final Set<String> owned;
  final Map<String, String> equipped;
}

final nimzoStoreProvider = FutureProvider.autoDispose<NimzoStoreSnapshot>(
  (ref) async {
    final session = ref.watch(sessionSupabaseProvider);
    final id = session.userId;
    if (id == null) throw StateError('Please sign in to view the Store.');

    final catalog = await session.client
        .from('nimzo_cosmetic_catalog')
        .select('id,category,name,variant,coin_price')
        .eq('active', true)
        .order('category')
        .order('variant');
    final ownership = await session.client
        .from('nimzo_cosmetic_ownership')
        .select('item_id')
        .eq('user_id', id);
    final equipped = await session.client
        .from('nimzo_cosmetic_equipped')
        .select('category,item_id')
        .eq('user_id', id);

    return NimzoStoreSnapshot(
      items: (catalog as List)
          .map((e) => NimzoCosmeticItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      owned: (ownership as List)
          .map((e) => (e as Map<String, dynamic>)['item_id'] as String)
          .toSet(),
      equipped: {
        for (final e in (equipped as List))
          (e as Map<String, dynamic>)['category'] as String:
              e['item_id'] as String,
      },
    );
  },
);

class NimzoLiveStore extends ConsumerStatefulWidget {
  const NimzoLiveStore({super.key, this.initialBag = false});

  final bool initialBag;

  @override
  ConsumerState<NimzoLiveStore> createState() => _NimzoLiveStoreState();
}

class _NimzoLiveStoreState extends ConsumerState<NimzoLiveStore> {
  late bool bag = widget.initialBag;
  String category = 'All';
  String? pending;

  static const categories = <String>[
    'All',
    'Avatar Frame',
    'Party Theme',
    'Rides',
    'Chat Bubble',
    'Live Frame',
    'Royal Badge',
  ];

  static const colors = <Color>[
    Color(0xffefbf65),
    Color(0xfff48cad),
    Color(0xffe9a08e),
    Color(0xffa395ed),
    Color(0xff55c6ab),
    Color(0xff79b8e8),
    Color(0xffd4a467),
  ];

  NimzoArt artFor(String type) => switch (type) {
        'Avatar Frame' => NimzoArt.frame,
        'Party Theme' => NimzoArt.theme,
        'Rides' => NimzoArt.entrance,
        'Chat Bubble' => NimzoArt.bubble,
        'Live Frame' => NimzoArt.live,
        'Royal Badge' => NimzoArt.crest,
        _ => NimzoArt.reward,
      };

  IconData categoryIcon(String type) => switch (type) {
        'Avatar Frame' => Icons.filter_frames_rounded,
        'Party Theme' => Icons.palette_rounded,
        'Rides' => Icons.directions_car_rounded,
        'Chat Bubble' => Icons.chat_bubble_rounded,
        'Live Frame' => Icons.crop_square_rounded,
        'Royal Badge' => Icons.workspace_premium_rounded,
        _ => Icons.storefront_rounded,
      };

  Future<void> doAction(NimzoCosmeticItem item, bool isOwned) async {
    if (pending != null) return;
    setState(() => pending = item.id);
    try {
      final session = ref.read(sessionSupabaseProvider);
      if (session.userId == null) throw StateError('Sign in required');
      if (isOwned) {
        await session.client.rpc(
          'nimzo_store_equip_free',
          params: {'p_item_id': item.id},
        );
      } else {
        if (item.coinPrice != 0) {
          throw StateError('Paid checkout is not available yet.');
        }
        await session.client.rpc(
          'nimzo_store_claim_free',
          params: {'p_item_id': item.id},
        );
      }
      ref.invalidate(nimzoStoreProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isOwned
              ? '${item.name} equipped'
              : '${item.name} added to Backpack'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to update Store: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => pending = null);
    }
  }

  Widget itemTile(NimzoCosmeticItem item, NimzoStoreSnapshot snap) {
    final isOwned = snap.owned.contains(item.id);
    final equipped = snap.equipped[item.category] == item.id;
    final busy = pending == item.id;
    final accent = colors[item.variant % colors.length];

    return InkWell(
      key: ValueKey('nimzo-store-preview-${item.id}'),
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => NimzoStoreFullPreview(
            item: item,
            owned: isOwned,
            equipped: equipped,
          ),
        ),
      ),
      child: Container(
        key: ValueKey('nimzo-store-item-${item.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: equipped ? const Color(0xff0a9d73) : const Color(0xffe8edea),
          width: equipped ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: ColoredBox(
                color: const Color(0xfff5f7f4),
                child: Center(
                  child: NimzoIdentityArt(
                    kind: artFor(item.category),
                    variant: item.variant,
                    color: accent,
                    size: 102,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text(
            item.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xff728179)),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 35,
            child: FilledButton(
              key: ValueKey('nimzo-store-action-${item.id}'),
              onPressed: busy || pending != null || equipped ||
                      (item.coinPrice != 0 && !isOwned)
                  ? null
                  : () => doAction(item, isOwned),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff078e69),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 5),
              ),
              child: busy
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                  : Text(
                      equipped
                          ? 'Equipped'
                          : isOwned
                              ? 'Equip'
                              : item.coinPrice == 0
                                  ? 'Collect free'
                                  : 'Not for sale',
                      style: const TextStyle(fontSize: 11),
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nimzoStoreProvider);
    return Scaffold(
      backgroundColor: const Color(0xfff7f9f7),
      appBar: AppBar(
        title: const Text('NIMZO Store',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff153d32),
        actions: [
          IconButton(
            tooltip: 'Refresh Store',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(nimzoStoreProvider),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
          child: Row(children: [
            Expanded(child: _tabButton(
              label: 'Store', selected: !bag, icon: Icons.storefront_rounded,
              onTap: () => setState(() => bag = false),
            )),
            const SizedBox(width: 10),
            Expanded(child: _tabButton(
              label: 'Backpack', selected: bag, icon: Icons.backpack_rounded,
              onTap: () => setState(() => bag = true),
            )),
          ]),
        ),
        if (!bag)
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final selected = category == categories[i];
                return ChoiceChip(
                  selected: selected,
                  label: Text(categories[i]),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xff385548),
                    fontSize: 11,
                  ),
                  selectedColor: const Color(0xff078e69),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => category = categories[i]),
                );
              },
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Original NIMZO cosmetic collection. Free items save to your '
              'Backpack; equipped designs sync with your account.',
              style: TextStyle(color: Color(0xff64766a), fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.store_mall_directory_outlined,
                    color: Color(0xff869b8f), size: 42),
                  const SizedBox(height: 12),
                  const Text('Store catalog unavailable',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Please retry. No coins have been charged.',
                    textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => ref.invalidate(nimzoStoreProvider),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            ),
            data: (snap) {
              final filtered = snap.items.where((item) =>
                  (!bag || snap.owned.contains(item.id)) &&
                  (bag || category == 'All' || item.category == category))
                .toList(growable: false);

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    bag
                      ? 'Your Backpack is empty. Collect a free item first.'
                      : 'No designs available in this category.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xff64766a)),
                  ),
                );
              }
              return LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth >= 680 ? 4
                    : constraints.maxWidth >= 460 ? 3 : 2;
                return GridView.builder(
                  key: ValueKey(bag ? 'store-backpack-grid' : 'store-catalog-grid'),
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 28),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 225,
                  ),
                  itemBuilder: (_, i) => itemTile(filtered[i], snap),
                );
              });
            },
          ),
        ),
      ]),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: selected ? const Color(0xff078e69) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20,
              color: selected ? Colors.white : const Color(0xff42665b)),
          const SizedBox(width: 7),
          Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xff42665b),
            )),
        ]),
      ),
    ),
  );
}


/// Full-screen, zoomable, replayable preview of the actual original NIMZO
/// vector item. This is a preview, NOT a purchase or ownership grant.
/// No third-party APK media is loaded or distributed by this screen.
class NimzoStoreFullPreview extends StatefulWidget {
  const NimzoStoreFullPreview({
    super.key,
    required this.item,
    required this.owned,
    required this.equipped,
  });

  final NimzoCosmeticItem item;
  final bool owned;
  final bool equipped;

  @override
  State<NimzoStoreFullPreview> createState() => _NimzoStoreFullPreviewState();
}

class _NimzoStoreFullPreviewState extends State<NimzoStoreFullPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  NimzoArt get art => switch (widget.item.category) {
        'Avatar Frame' => NimzoArt.frame,
        'Party Theme' => NimzoArt.theme,
        'Rides' => NimzoArt.entrance,
        'Chat Bubble' => NimzoArt.bubble,
        'Live Frame' => NimzoArt.live,
        'Royal Badge' => NimzoArt.crest,
        _ => NimzoArt.reward,
      };

  static const accents = <Color>[
    Color(0xffefbf65),
    Color(0xfff48cad),
    Color(0xffe9a08e),
    Color(0xffa395ed),
    Color(0xff55c6ab),
    Color(0xff79b8e8),
    Color(0xffd4a467),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = accents[item.variant % accents.length];
    final canvas = (MediaQuery.sizeOf(context).width * .84)
        .clamp(180.0, 390.0)
        .toDouble();
    return Scaffold(
      key: const ValueKey('nimzo-store-full-preview'),
      backgroundColor: const Color(0xfff7f9f7),
      appBar: AppBar(
        title: Text(item.name),
        centerTitle: true,
        foregroundColor: const Color(0xff153d32),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: .7,
                  maxScale: 3,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (_, __) => NimzoIdentityArt(
                      kind: art,
                      variant: item.variant,
                      color: color,
                      size: canvas,
                      progress: MediaQuery.disableAnimationsOf(context)
                          ? 1
                          : controller.value,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 22)),
                  const SizedBox(height: 5),
                  Text(item.category,
                    style: const TextStyle(color: Color(0xff64766a))),
                  const SizedBox(height: 12),
                  Text(
                    widget.equipped
                        ? 'Equipped'
                        : widget.owned
                            ? 'In your Backpack'
                            : 'Preview only — not yet owned',
                    key: const ValueKey('nimzo-preview-ownership-status'),
                    style: const TextStyle(color: Color(0xff587666)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('nimzo-preview-replay'),
                      onPressed: () {
                        if (MediaQuery.disableAnimationsOf(context)) {
                          controller.value = 1;
                        } else {
                          controller.forward(from: 0);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Replay full preview'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff078e69)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Original NIMZO design. Preview does not charge coins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11,
                      color: Color(0xff64766a)),
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
