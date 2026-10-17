import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../profile/profile_collections.dart';
import 'store_badge.dart';
import '../wallet/wallet_screen.dart';
import 'store_repository.dart';

class RoyalStoreScreen extends ConsumerStatefulWidget {
  const RoyalStoreScreen({super.key, this.initialBag = false});
  final bool initialBag;
  @override
  ConsumerState<RoyalStoreScreen> createState() => _RoyalStoreScreenState();
}

class _RoyalStoreScreenState extends ConsumerState<RoyalStoreScreen> {
  late bool bag;
  String category = 'Medals';
  @override
  void initState() {
    super.initState();
    bag = widget.initialBag;
  }
  String? busy;
  String? pendingKey;
  String? pendingItem;

  void refresh(String id) {
    ref.invalidate(royalBagProvider(id));
    ref.invalidate(walletProvider);
    ref.invalidate(profileCollectionProvider((id, ProfileCollection.medal)));
    ref.invalidate(equippedRoyalMedalProvider(id));
  }

  Future<void> purchase(RoyalStoreItem item, String id) async {
    if (busy != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Buy ${item.name}?'),
        content: Text(
          '${compactNumber(item.price)} coins will be deducted once. The medal is permanent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = item.id);
    if (pendingItem != item.id) {
      pendingItem = item.id;
      pendingKey = ref.read(royalStoreRepositoryProvider).newPurchaseKey();
    }
    try {
      await ref.read(royalStoreRepositoryProvider).buy(item.id, pendingKey!);
      if (!mounted) return;
      pendingItem = null;
      pendingKey = null;
      refresh(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchased. Find it in your Bag.')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase not confirmed: $e. Retry the same item to check.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> equip(String id, String itemId) async {
    if (busy != null) return;
    setState(() => busy = itemId);
    try {
      await ref.read(royalStoreRepositoryProvider).equip(itemId);
      if (!mounted) return;
      refresh(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medal equipped on your profile.')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not equip medal: $e')));
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Widget artwork(String path) => Image.asset(
        path,
        width: 66,
        height: 66,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined, size: 46),
      );

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: const Color(0xffebeaff),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xffb4b7ff),
        foregroundColor: Colors.white,
        title: const Text('My Store',
          style: TextStyle(fontWeight: FontWeight.w900,
            color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Open Backpack',
            onPressed: () => setState(() => bag = true),
            icon: const Icon(Icons.inventory_2_outlined,
              color: NimzoStyle.primary),
          ),
        ],
      ),
      body: id == null
          ? const Center(child: Text('Sign in to use the Store.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(royalCatalogProvider);
                refresh(id);
                await ref.read(royalCatalogProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(13, 14, 13, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xff817cde), Color(0xffb5a2ef)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x248b3dff),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'NIMZO Collection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push('/wallet'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                              ),
                              label: const Text('Wallet'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ref.watch(walletProvider).when(
                          data: (balance) => Text(
                            '${compactNumber(balance.coins)} coins available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          loading: () => const LinearProgressIndicator(
                            color: Colors.white,
                          ),
                          error: (_, __) => const Text(
                            'Wallet balance unavailable',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Store'),
                        icon: Icon(Icons.storefront_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('My Bag'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {bag},
                    onSelectionChanged: (v) => setState(() => bag = v.first),
                  ),
                  const SizedBox(height: 14),
                  if (!bag) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        for (final c in const <({
                          String value, String label, IconData icon, Color color
                        })>[
                          (value: 'Frames', label: 'Avatar Frame',
                            icon: Icons.filter_frames_rounded,
                            color: Color(0xffa546e7)),
                          (value: 'Entry', label: 'Party Theme',
                            icon: Icons.palette_rounded,
                            color: Color(0xffab32e2)),
                          (value: 'Rides', label: 'Rides',
                            icon: Icons.directions_car_rounded,
                            color: Color(0xfff4a20c)),
                          (value: 'Bubbles', label: 'Chat Bubble',
                            icon: Icons.chat_bubble_rounded,
                            color: Color(0xff12adf3)),
                          (value: 'LiveFrames', label: 'Live Frame',
                            icon: Icons.crop_square_rounded,
                            color: Color(0xfff05eaa)),
                          (value: 'Medals', label: 'Featured',
                            icon: Icons.workspace_premium_rounded,
                            color: Color(0xffef9b26)),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              key: ValueKey('store-category-${c.value}'),
                              onTap: () {
                                setState(() => category = c.value);
                                if (c.value != 'Medals') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => StoreCategoryPreview(
                                        category: c.label,
                                        icon: c.icon,
                                        accent: c.color,
                                      ),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Column(children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 60, height: 62,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: category == c.value
                                        ? NimzoStyle.primary
                                        : const Color(0xfff1e9fe),
                                      width: category == c.value ? 2 : 1)),
                                  child: Icon(c.icon,
                                    color: c.color, size: 32),
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  width: 70,
                                  child: Text(c.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: category == c.value
                                        ? FontWeight.w800 : FontWeight.w500,
                                      color: const Color(0xff77648f)),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    const Text('Hot recommendation',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                        color: Color(0xff18141f))),
                    const SizedBox(height: 13),
                  ],
                  if (!bag && category != 'Medals')
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Column(children: [
                        const Icon(Icons.inventory_2_outlined,
                          size: 46, color: Color(0xffb0a0d4)),
                        const SizedBox(height: 15),
                        Text('No active $category catalog',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 9),
                        const Text(
                          'Only verified store items with real coin prices '
                          'and purchase settlement can be shown here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NimzoStyle.muted)),
                      ]),
                    )
                  else if (!bag)
                    ref.watch(royalCatalogProvider).when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => _error(
                            e,
                            () => ref.invalidate(royalCatalogProvider),
                          ),
                          data: (items) => items.isEmpty
                              ? const Text('No Royal collectibles on sale.')
                              : FutureBuilder<List<RoyalBagItem>>(
                                  future: ref.watch(
                                    royalBagProvider(id).future,
                                  ),
                                  builder: (ctx, snapshot) {
                                    if (snapshot.hasError)
                                      return _error(
                                        snapshot.error!,
                                        () => ref.invalidate(
                                          royalBagProvider(id),
                                        ),
                                      );
                                    if (!snapshot.hasData)
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    final owned =
                                        snapshot.data!.map((x) => x.id).toSet();
                                    return _grid([
                                      for (final item in items)
                                        _card(
                                          item.name,
                                          item.image,
                                          '${compactNumber(item.price)} coins',
                                          owned.contains(item.id)
                                              ? 'Owned'
                                              : 'Buy',
                                          owned.contains(item.id) ||
                                                  busy != null
                                              ? null
                                              : () => purchase(item, id),
                                        ),
                                    ]);
                                  },
                                ),
                        )
                  else
                    ref.watch(royalBagProvider(id)).when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => _error(
                            e,
                            () => ref.invalidate(royalBagProvider(id)),
                          ),
                          data: (items) => items.isEmpty
                              ? const Text(
                                  'Your Bag is empty. Buy a Royal collectible in Store.',
                                )
                              : _grid([
                                  for (final item in items)
                                    _card(
                                      item.name,
                                      item.image,
                                      item.equipped
                                          ? 'Visible on profile'
                                          : 'Owned permanently',
                                      item.equipped ? 'Equipped' : 'Equip',
                                      item.equipped || busy != null
                                          ? null
                                          : () => equip(id, item.id),
                                    ),
                                ]),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _error(Object error, VoidCallback retry) => Column(
        children: [
          Text('Store data unavailable: $error'),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      );

  Widget _grid(List<Widget> cards) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 650 ? 3 : 2;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            childAspectRatio: .77,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: cards,
          );
        },
      );

  Widget _card(
    String name,
    String image,
    String detail,
    String action,
    VoidCallback? onTap,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: NimzoStyle.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x116628cf),
              blurRadius: 9,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Center(child: artwork(image))),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              detail,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                child:
                    Text(busy != null && onTap != null ? 'Working…' : action),
              ),
            ),
          ],
        ),
      );
}

/// UI-only collection preview for product categories whose server catalog
/// is not yet verified. No prices, fake ownership, charges, or checkout.
/// The supplied screenshot establishes layout, not saleable inventory.
class StoreCategoryPreview extends StatefulWidget {
  final String category;
  final IconData icon;
  final Color accent;
  const StoreCategoryPreview({
    super.key, required this.category, required this.icon,
    required this.accent,
  });

  @override
  State<StoreCategoryPreview> createState() => _StoreCategoryPreviewState();
}

class _StoreCategoryPreviewState extends State<StoreCategoryPreview> {
  int selected = 0;
  static const styles = <({String name, IconData icon})>[
    (name: 'Golden Stars', icon: Icons.stars_rounded),
    (name: 'Kiss Me', icon: Icons.favorite_outline_rounded),
    (name: 'Cherry Blossom', icon: Icons.local_florist_rounded),
    (name: 'Neon', icon: Icons.auto_awesome_rounded),
    (name: 'Floral', icon: Icons.spa_rounded),
    (name: 'Hearts', icon: Icons.favorite_rounded),
    (name: 'Royal', icon: Icons.diamond_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      const Color(0xffffd277), const Color(0xfff577bf),
      const Color(0xfff49bb6), const Color(0xffb48afa),
      const Color(0xff91e7c4), const Color(0xff7dc6f7),
      const Color(0xffeac19b),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.category,
          style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xffabb2fa),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          child: Row(children: [
            Expanded(child: Text(styles[selected].name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            const Chip(
              key: ValueKey('store-category-preview-only'),
              label: Text('Preview only'),
              avatar: Icon(Icons.visibility_outlined, size: 17),
            ),
          ]),
        ),
      ),
      body: ListView(
        key: const ValueKey('store-category-preview'),
        children: [
          Container(
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffb3b7ff), Color(0xfff8f7ff)],
              ),
            ),
            alignment: Alignment.center,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 167, height: 167,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors[selected], width: 7),
                  boxShadow: [
                    BoxShadow(
                      color: colors[selected].withValues(alpha: .45),
                      blurRadius: 17, spreadRadius: 8),
                  ]),
              ),
              CircleAvatar(
                radius: 64,
                backgroundColor: const Color(0xffefe9ff),
                child: Icon(widget.icon,
                  color: widget.accent, size: 62),
              ),
              SizedBox(
                width: 189, height: 189,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 3,
                  color: colors[selected],
                  backgroundColor: Colors.transparent,
                ),
              ),
              Positioned(
                top: 15,
                child: Icon(styles[selected].icon,
                  size: 35, color: colors[selected])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.category, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Original design previews · items are not available '
              'for purchase until a verified catalog is connected.',
              style: TextStyle(fontSize: 11, color: Color(0xff8b8298)),
            ),
          ),
          const SizedBox(height: 13),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: styles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 9,
              childAspectRatio: .80,
            ),
            itemBuilder: (context, index) => InkWell(
              key: ValueKey('store-preview-style-$index'),
              borderRadius: BorderRadius.circular(17),
              onTap: () => setState(() => selected = index),
              child: Column(children: [
                Expanded(child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f2ff),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected == index
                        ? const Color(0xffa343ed)
                        : Colors.transparent,
                      width: 2),
                  ),
                  child: Center(
                    child: Icon(styles[index].icon,
                      size: 48, color: colors[index]),
                  ),
                )),
                const SizedBox(height: 5),
                Text(styles[index].name, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
