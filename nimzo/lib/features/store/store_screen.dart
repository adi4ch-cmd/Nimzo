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
      backgroundColor: const Color(0xfff6f5ff),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Store',
          style: TextStyle(fontWeight: FontWeight.w900,
            color: Color(0xff231638))),
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
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: NimzoStyle.heroGradient,
                      borderRadius: BorderRadius.circular(20),
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
                                  fontSize: 21,
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  if (!bag) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final name in const [
                          'Medals', 'Frames', 'Entry', 'Bubbles', 'Rides',
                        ]) Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(name),
                            selected: category == name,
                            onSelected: (_) =>
                              setState(() => category = name),
                            selectedColor: const Color(0xffeadbff),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: category == name
                                ? NimzoStyle.primary
                                : const Color(0xff786e91),
                              fontWeight: FontWeight.w700),
                            side: BorderSide(
                              color: category == name
                                ? NimzoStyle.primary
                                : NimzoStyle.line),
                            showCheckmark: false,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 15),
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
