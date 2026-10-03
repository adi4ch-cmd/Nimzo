import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'gift_repository.dart';

const giftCategories = ['All', 'Classic', 'Premium', 'VIP', 'SVIP'];

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
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Row(children: [const Expanded(child: Text('Send a gift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Text('${selected?.name ?? 'Choose one'}', style: Theme.of(context).textTheme.bodySmall)])),
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
                          Icon(
                            switch (g.category.toLowerCase()) {
                              'classic' => Icons.favorite_rounded,
                              'premium' => Icons.diamond_rounded,
                              'vip' => Icons.workspace_premium_rounded,
                              'svip' => Icons.auto_awesome_rounded,
                              _ => Icons.card_giftcard_rounded,
                            },
                            size: 28, color: selected?.id == g.id ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ), const SizedBox(height: 4),
                          Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), Text('${g.price} coins', style: Theme.of(context).textTheme.bodySmall)]),
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
