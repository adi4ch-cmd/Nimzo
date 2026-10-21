import 'dart:math';

import 'store_visual_equipment.dart';
import 'store_purchase_repository.dart';
import '../wallet/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_cosmetics.dart';
import 'cosmetic_media_view.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';

/// Account catalog with pinned media for imported items and original vector art.
class NimzoCosmeticItem {
  const NimzoCosmeticItem({
    required this.id,
    required this.category,
    required this.name,
    required this.variant,
    required this.coinPrice,
    this.thumbnailUrl,
    this.assetUrl,
    this.mediaKind,
  });

  final String id;
  final String category;
  final String name;
  final int variant;
  final int coinPrice;
  final String? thumbnailUrl;
  final String? assetUrl;
  final CosmeticMediaKind? mediaKind;

  /// Only a server-approved, validated asset can be rendered or equipped.
  CosmeticMedia? get remoteMedia => assetUrl == null || mediaKind == null
      ? null
      : CosmeticMedia(id, category, name, assetUrl!, mediaKind!,
          thumbnail: thumbnailUrl);

  factory NimzoCosmeticItem.fromJson(Map<String, dynamic> json) {
    String? httpsUrl(Object? input) {
      final uri = Uri.tryParse(input is String ? input : '');
      return uri != null &&
              uri.scheme == 'https' &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
          ? uri.toString()
          : null;
    }

    final kind = switch (json['media_kind']) {
      'image' => CosmeticMediaKind.image,
      'svga' => CosmeticMediaKind.svga,
      'vap' => CosmeticMediaKind.vap,
      _ => null,
    };
    return NimzoCosmeticItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      variant: (json['variant'] as num).toInt(),
      coinPrice: (json['coin_price'] as num).toInt(),
      thumbnailUrl: httpsUrl(json['thumbnail_url']),
      assetUrl: httpsUrl(json['asset_url']),
      mediaKind: kind,
    );
  }
}

/// Only existing, reviewed bundled assets or approved playable remote media
/// are considered real Store products. A thumbnail alone is not an item.
bool hasVerifiedStoreMedia(NimzoCosmeticItem item) =>
    item.remoteMedia != null || premiumCosmetics.containsKey(item.id);

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
    // Approved server image previews are optional; bundled previews remain
    // available for items without remote media.
    final remoteMedia = await session.client
        .from('nimzo_cosmetic_media')
        .select('item_id,thumbnail_url,asset_url,media_kind')
        .eq('approved', true);
    final approved = <String, Map<String, dynamic>>{
      for (final e in remoteMedia)
        if (e['item_id'] is String)
          e['item_id'] as String: Map<String, dynamic>.from(e),
    };
    final ownership = await session.client
        .from('nimzo_cosmetic_ownership')
        .select('item_id')
        .eq('user_id', id);
    final equipped = await session.client
        .from('nimzo_cosmetic_equipped')
        .select('category,item_id')
        .eq('user_id', id);

    // Interleave different product types in the All tab instead of showing
    // seven nearly identical badges in a row (the v1.0.31 screenshot issue).
    final items = (catalog as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      row.addAll(approved[row['id']] ?? const <String, dynamic>{});
      return NimzoCosmeticItem.fromJson(row);
    }).toList();
    const order = <String>[
      'Avatar Frame',
      'Rides',
      'Party Theme',
      'Chat Bubble',
      'Live Frame',
      'Royal Badge',
      'ID Frame',
      'Profile Card',
      'Mic Wave',
    ];
    items.sort((a, b) {
      final byVariant = a.variant.compareTo(b.variant);
      if (byVariant != 0) return byVariant;
      return order.indexOf(a.category).compareTo(order.indexOf(b.category));
    });
    return NimzoStoreSnapshot(
      items: items,
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
  // Stable retry key + server ownership guard prevent duplicate charging.
  final Map<String, String> _purchaseKeys = {};

  static const categories = <String>[
    'All',
    'Avatar Frame',
    'Party Theme',
    'Rides',
    'Chat Bubble',
    'Live Frame',
    'Royal Badge',
    'ID Frame',
    'Profile Card',
    'Mic Wave',
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

  Future<void> doAction(
      NimzoCosmeticItem item, bool isOwned, bool equipped) async {
    if (pending != null) return;
    setState(() => pending = item.id);
    final session = ref.read(sessionSupabaseProvider);
    try {
      dynamic confirmed;
      if (session.userId == null) throw StateError('Sign in required');
      if (equipped) {
        confirmed = await session.client
            .rpc('nimzo_store_unequip', params: {'p_category': item.category});
      } else if (isOwned) {
        confirmed = await session.client.rpc(
          'nimzo_store_equip_free',
          params: {'p_item_id': item.id},
        );
      } else if (item.coinPrice == 0) {
        confirmed = await session.client.rpc(
          'nimzo_store_claim_free',
          params: {'p_item_id': item.id},
        );
      } else {
        if (item.remoteMedia == null) {
          throw StateError('Item media not ready. No coins charged.');
        }
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Confirm Store purchase'),
            content: Text(
              'Buy ${item.name} for ${item.coinPrice} coins? '
              'The server verifies the final price.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Buy'),
              ),
            ],
          ),
        );
        if (!mounted ||
            accepted != true ||
            ref.read(sessionSupabaseProvider).userId != session.userId) return;
        final key = _purchaseKeys.putIfAbsent(
          item.id,
          () => List.generate(
              16,
              (_) => Random.secure()
                  .nextInt(256)
                  .toRadixString(16)
                  .padLeft(2, '0')).join(),
        );
        await NimzoStorePurchaseRepository(session.client).purchase(
          itemId: item.id,
          expectedPrice: item.coinPrice,
          retryKey: key,
        );
        confirmed = true;
        _purchaseKeys.remove(item.id);
        ref.invalidate(walletProvider);
      }
      if (confirmed != true) {
        throw StateError('Server did not confirm the update.');
      }
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) {
        return;
      }
      ref.invalidate(nimzoStoreProvider);
      ref.invalidate(storeVisualEquipmentProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(equipped
              ? '${item.name} removed'
              : isOwned
                  ? '${item.name} equipped'
                  : '${item.name} added to Backpack'),
        ));
      }
    } catch (error) {
      // Network failures may occur after the server commits a purchase.
      ref.invalidate(nimzoStoreProvider);
      ref.invalidate(walletProvider);
      if (mounted &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
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
    final hasRealMedia = hasVerifiedStoreMedia(item);

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
          color: const Color(0xff2b2031),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: equipped ? const Color(0xffefc983) : const Color(0xff493650),
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
                  color: const Color(0xff241a2b),
                  child: Center(
                    child: item.thumbnailUrl != null
                        ? Image.network(
                            item.thumbnailUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          )
                        : premiumCosmetics[item.id] != null
                            ? CosmeticMediaView(
                                key: ValueKey(item.id),
                                media: premiumCosmetics[item.id]!,
                                animate: false)
                            : const Icon(Icons.image_not_supported_outlined,
                                semanticLabel: 'Item media unavailable'),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xffefc983)),
            ),
            Text(
              item.coinPrice > 0
                  ? '${item.category} · ${item.coinPrice} coins'
                  : item.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xffc5b5cd)),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 35,
              child: FilledButton(
                key: ValueKey('nimzo-store-action-${item.id}'),
                onPressed: busy ||
                        pending != null ||
                        !hasRealMedia ||
                        (item.coinPrice > 0 &&
                            !isOwned &&
                            item.remoteMedia == null)
                    ? null
                    : () => doAction(item, isOwned, equipped),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffefc983),
                  foregroundColor: const Color(0xff28182c),
                  disabledBackgroundColor: const Color(0xff493650),
                  disabledForegroundColor: const Color(0xffc5b5cd),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                ),
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        !hasRealMedia
                            ? 'Artwork unavailable'
                            : equipped
                            ? 'Remove'
                            : isOwned
                                ? 'Equip'
                                : item.coinPrice == 0
                                    ? 'Collect free'
                                    : item.remoteMedia != null
                                        ? 'Buy'
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
      backgroundColor: const Color(0xff17121e),
      appBar: AppBar(
        title: const Text('NIMZO Store',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xff17121e),
        foregroundColor: const Color(0xffefc983),
        actions: [
          IconButton(
            tooltip: 'Refresh Store',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(nimzoStoreProvider),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
            child: Row(children: [
              Expanded(
                  child: _tabButton(
                label: 'Store',
                selected: !bag,
                icon: Icons.storefront_rounded,
                onTap: () => setState(() => bag = false),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _tabButton(
                label: 'Backpack',
                selected: bag,
                icon: Icons.backpack_rounded,
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
                      color: selected
                          ? const Color(0xff28182c)
                          : const Color(0xffdbc9e2),
                      fontSize: 11,
                    ),
                    selectedColor: const Color(0xffefc983),
                    backgroundColor: const Color(0xff17121e),
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
                'Choose your look. Collected items save to your '
                'Backpack; equipped designs sync with your account.',
                style: TextStyle(color: Color(0xffc5b5cd), fontSize: 11),
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
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffefc983))),
                    const SizedBox(height: 6),
                    const Text('Please retry. No coins have been charged.',
                        style: TextStyle(color: Color(0xffc5b5cd)),
                        textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.invalidate(nimzoStoreProvider),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              ),
              data: (snap) {
                final filtered = snap.items
                    .where((item) =>
                        (!bag || snap.owned.contains(item.id)) &&
                        (bag || hasVerifiedStoreMedia(item)) &&
                        (bag || category == 'All' || item.category == category))
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      bag
                          ? 'Your Backpack is empty. Collect a free item first.'
                          : 'No designs available in this category.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xffc5b5cd)),
                    ),
                  );
                }
                return LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 680
                      ? 4
                      : constraints.maxWidth >= 460
                          ? 3
                          : 2;
                  return GridView.builder(
                    key: ValueKey(
                        bag ? 'store-backpack-grid' : 'store-catalog-grid'),
                    padding: const EdgeInsets.fromLTRB(15, 6, 15, 60),
                    itemCount: filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 225 +
                          (MediaQuery.textScalerOf(context).scale(48) - 48),
                    ),
                    itemBuilder: (_, i) => itemTile(filtered[i], snap),
                  );
                });
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      Material(
        color: selected ? const Color(0xffefc983) : const Color(0xff2b2031),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? const Color(0xff28182c)
                      : const Color(0xffdbc9e2)),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xff28182c)
                        : const Color(0xffdbc9e2),
                  )),
            ]),
          ),
        ),
      );
}

/// Full preview uses the same pinned item media as the Store card.
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

  int replay = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = accents[item.variant % accents.length];
    final media = premiumCosmetics[item.id];
    final animatedMedia =
        media != null && media.kind != CosmeticMediaKind.image;
    final canvas =
        (MediaQuery.sizeOf(context).width * .84).clamp(180.0, 390.0).toDouble();
    return Scaffold(
      key: const ValueKey('nimzo-store-full-preview'),
      backgroundColor: const Color(0xff17121e),
      appBar: AppBar(
        title: Text(item.name),
        centerTitle: true,
        foregroundColor: const Color(0xffefc983),
        backgroundColor: const Color(0xff17121e),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: .7,
                  maxScale: 3,
                  child: item.remoteMedia != null
                      ? SizedBox(
                          width: canvas,
                          height: canvas,
                          child: CosmeticMediaView(
                            key: ValueKey('remote-${item.id}-$replay'),
                            media: item.remoteMedia!,
                            animate: !MediaQuery.disableAnimationsOf(context),
                          ),
                        )
                      : item.thumbnailUrl != null
                          ? Image.network(
                              item.thumbnailUrl!,
                              width: canvas,
                              height: canvas,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            )
                          : premiumCosmetics[item.id] != null
                              ? SizedBox(
                                  width: canvas,
                                  height: canvas,
                                  child: CosmeticMediaView(
                                      key: ValueKey('${item.id}-$replay'),
                                      media: premiumCosmetics[item.id]!,
                                      animate: !MediaQuery.disableAnimationsOf(
                                          context)))
                              : const Icon(
                                  Icons.image_not_supported_outlined,
                                  semanticLabel: 'Item media unavailable'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Color(0xffefc983))),
                  const SizedBox(height: 5),
                  Text(item.category,
                      style: const TextStyle(color: Color(0xffc5b5cd))),
                  const SizedBox(height: 12),
                  Text(
                    widget.equipped
                        ? 'Equipped'
                        : widget.owned
                            ? 'In your Backpack'
                            : 'Preview only — not yet owned',
                    key: const ValueKey('nimzo-preview-ownership-status'),
                    style: const TextStyle(color: Color(0xffc5b5cd)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('nimzo-preview-replay'),
                      onPressed: () {
                        setState(() => replay++);
                        if (MediaQuery.disableAnimationsOf(context)) {
                          controller.value = 1;
                        } else {
                          controller.forward(from: 0);
                        }
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(animatedMedia
                          ? 'Replay animation'
                          : media != null
                              ? 'View artwork again'
                              : 'Replay artwork transition'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffefc983),
                          foregroundColor: const Color(0xff28182c)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media != null
                        ? '${animatedMedia ? 'Animated media' : 'Static artwork'} · No coins charged. Badges are decorative cosmetics.'
                        : item.id.startsWith('nimzo-original-')
                            ? 'Original NIMZO design · Artwork transition only. No coins charged.'
                            : 'Item media unavailable · No coins charged.',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xffc5b5cd)),
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
