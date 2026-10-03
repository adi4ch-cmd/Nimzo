import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import '../../core/utils/helpers.dart';
import 'gift_repository.dart';

const giftCategories = ['All', 'Classic', 'Premium', 'VIP', 'SVIP'];

final myCoinBalanceProvider = FutureProvider<int>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;
  final row = await Supabase.instance.client.from('wallets').select('coins').eq('user_id', userId).maybeSingle();
  return (row?['coins'] as num?)?.toInt() ?? 0;
});

void showGiftSheet(BuildContext c, String roomId, String receiverId) => showModalBottomSheet(
    context: c, isScrollControlled: true, builder: (_) => GiftSheet(roomId: roomId, receiverId: receiverId));

class GiftSheet extends ConsumerStatefulWidget {
  final String roomId, receiverId;
  const GiftSheet({super.key, required this.roomId, required this.receiverId});
  @override
  ConsumerState<GiftSheet> createState() => _S();
}

class _S extends ConsumerState<GiftSheet> {
  int qty = 1;
  String cat = 'All';
  Gift? selected;
  bool busy = false;
  final _custom = TextEditingController();
  @override
  void dispose() { _custom.dispose(); super.dispose(); }

  Future<void> _send() async {
    final g = selected;
    if (g == null) return;
    final currentUser = Supabase.instance.client.auth.currentUser?.id;
    if (currentUser != null && currentUser == widget.receiverId) {
      _snack('You cannot send a gift to yourself');
      return;
    }
    final n = _custom.text.isNotEmpty ? int.tryParse(_custom.text) ?? 0 : qty;
    if (n < 1 || n > 9999) { _snack('Enter a quantity from 1 to 9999'); return; }
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Confirm gift'),
              content: Text('Send $n x ${g.name} for ${g.price * n} coins?'),
              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Send'))],
            ));
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await ref.read(giftRepositoryProvider).send(
          roomId: widget.roomId, receiverId: widget.receiverId, giftId: g.id, qty: n,
          key: '${DateTime.now().microsecondsSinceEpoch}-${g.id}');
      ref.invalidate(myCoinBalanceProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) { _snack('$e'); } finally { if (mounted) setState(() => busy = false); }
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(giftCatalogProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: 520,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(children: [
                const Expanded(child: Text('Send a gift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ref.watch(myCoinBalanceProvider).when(
                  loading: () => const SizedBox(width: 54, height: 28, child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))),
                  error: (_, __) => const _CoinPill(value: 0),
                  data: (coins) => _CoinPill(value: coins),
                ),
              ]),
            ),
            SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
              for (final c in giftCategories)
                Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c)))
            ])),
            Expanded(child: catalog.when(
              loading: () => const ShimmerView(rows: 4),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(giftCatalogProvider)),
              data: (all) {
                final list = cat == 'All' ? all : all.where((g) => g.category.toLowerCase() == cat.toLowerCase()).toList();
                if (list.isEmpty) return const EmptyView(title: 'No gifts in this category');
                return GridView.count(crossAxisCount: 4, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
                  for (final g in list)
                    InkWell(
                      onTap: () => setState(() => selected = g),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected?.id == g.id ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0), width: selected?.id == g.id ? 2 : 1)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _GiftVisual(gift: g, selected: selected?.id == g.id),
                          const SizedBox(height: 4),
                          Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), _CoinPrice(value: g.price)]),
                      ),
                    )
                ]);
              },
            )),
            Padding(padding: const EdgeInsets.all(8), child: Row(children: [
              for (final q in [1, 2, 5, 10]) Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text('$q'), selected: qty == q && _custom.text.isEmpty, onSelected: (_) => setState(() { qty = q; _custom.clear(); }))),
              SizedBox(width: 64, child: TextField(controller: _custom, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Custom', isDense: true), onChanged: (_) => setState(() {}))),
              const Spacer(),
              FilledButton(onPressed: busy || selected == null ? null : _send, child: const Text('Send')),
            ])),
          ]),
        ),
      ),
    );
  }
}


class _GiftVisual extends StatelessWidget {
  final Gift gift;
  final bool selected;
  const _GiftVisual({required this.gift, required this.selected});
  @override
  Widget build(BuildContext context) {
    final fallback = switch (gift.category.toLowerCase()) {
      'classic' => Icons.favorite_rounded,
      'premium' => Icons.diamond_rounded,
      'vip' => Icons.workspace_premium_rounded,
      'svip' => Icons.auto_awesome_rounded,
      _ => Icons.card_giftcard_rounded,
    };
    final color = selected ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    if (gift.assetPath == null || gift.assetPath!.trim().isEmpty) return Icon(fallback, size: 30, color: color);
    final url = storageUrl(Supabase.instance.client, 'gifts', gift.assetPath);
    if (url == null) return Icon(fallback, size: 30, color: color);
    return SizedBox(width: 42, height: 42, child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(fallback, size: 30, color: color)));
  }
}

class _CoinPill extends StatelessWidget {
  final int value;
  const _CoinPill({required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFFFF7D6), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFF1D77A))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.monetization_on_rounded, size: 17, color: Color(0xFFD59B00)),
      const SizedBox(width: 5),
      Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    ]),
  );
}

class _CoinPrice extends StatelessWidget {
  final int value;
  const _CoinPrice({required this.value});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.monetization_on_rounded, size: 13, color: Color(0xFFD59B00)),
    const SizedBox(width: 2),
    Flexible(child: Text(value.toString(), style: Theme.of(context).textTheme.bodySmall)),
  ]);
}
