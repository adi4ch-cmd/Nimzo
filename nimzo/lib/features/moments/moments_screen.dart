import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'moment_repository.dart';
import '../gifts/gift_repository.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Moments')),
      floatingActionButton: FloatingActionButton(onPressed: () => context.push('/moments/create'), child: const Icon(Icons.add)),
      body: ref.watch(momentsFeedProvider).when(
        loading: () => const ShimmerView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(momentsFeedProvider)),
        data: (list) => list.isEmpty
            ? const EmptyView(title: 'No moments yet', hint: 'Be the first to post.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(momentsFeedProvider),
                child: ListView.separated(
                  itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final repo = ref.read(momentRepositoryProvider);
                    return ListTile(
                      onTap: () => context.push('/moments/${m.id}'),
                      title: Text(m.text ?? ''),
                      subtitle: Row(children: [
                        IconButton(icon: Icon(m.liked ? Icons.favorite : Icons.favorite_border, size: 18),
                            onPressed: () async { await repo.toggleLike(m.id); ref.invalidate(momentsFeedProvider); }),
                        Text('${m.likes}'), const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline, size: 16), const SizedBox(width: 4), Text('${m.comments}'),
                        IconButton(icon: const Icon(Icons.card_giftcard_outlined, size: 19), tooltip: 'Send gift', onPressed: () => showMomentGiftSheet(context, m.id, m.authorId)),
                        const Spacer(), Text(timeAgo(m.createdAt)),
                      ]),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') await repo.delete(m.id); else await repo.report(m.id, 'user_report');
                          ref.invalidate(momentsFeedProvider);
                        },
                        itemBuilder: (_) => [
                          if (m.authorId == me) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          const PopupMenuItem(value: 'report', child: Text('Report')),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class CreateMomentScreen extends ConsumerStatefulWidget {
  const CreateMomentScreen({super.key});
  @override
  ConsumerState<CreateMomentScreen> createState() => _C();
}

class _C extends ConsumerState<CreateMomentScreen> {
  final _t = TextEditingController();
  bool busy = false;
  @override
  void dispose() { _t.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New moment'), actions: [
          TextButton(
            onPressed: busy || _t.text.trim().isEmpty ? null : () async {
              setState(() => busy = true);
              try {
                await ref.read(momentRepositoryProvider).create(text: _t.text.trim());
                ref.invalidate(momentsFeedProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              } finally { if (mounted) setState(() => busy = false); }
            },
            child: const Text('Post'),
          ),
        ]),
        body: Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _t, maxLines: null, maxLength: 500, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'What is on your mind?'))),
      );
}

class MomentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const MomentDetailScreen({super.key, required this.id});
  @override
  ConsumerState<MomentDetailScreen> createState() => _D();
}

class _D extends ConsumerState<MomentDetailScreen> {
  final _c = TextEditingController();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Column(children: [
          Expanded(child: ref.watch(commentsProvider(widget.id)).when(
            loading: () => const ShimmerView(rows: 4),
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(commentsProvider(widget.id))),
            data: (l) => l.isEmpty ? const EmptyView(title: 'No comments yet') : ListView(children: [for (final c in l) ListTile(title: Text(c['body']))]),
          )),
          SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: 'Add a comment'))),
            IconButton(icon: const Icon(Icons.send), onPressed: () async {
              if (_c.text.trim().isEmpty) return;
              await ref.read(momentRepositoryProvider).addComment(widget.id, _c.text.trim());
              _c.clear();
              ref.invalidate(commentsProvider(widget.id));
            }),
          ]))),
        ]),
      );
}


class _MomentGiftSheet extends ConsumerStatefulWidget {
  final String momentId, receiverId;
  const _MomentGiftSheet({required this.momentId, required this.receiverId});
  @override ConsumerState<_MomentGiftSheet> createState() => _MomentGiftSheetState();
}

void showMomentGiftSheet(BuildContext context, String momentId, String receiverId) =>
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _MomentGiftSheet(momentId: momentId, receiverId: receiverId));

class _MomentGiftSheetState extends ConsumerState<_MomentGiftSheet> {
  Gift? selected;
  int qty = 1;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftCatalogProvider);
    return SafeArea(child: SizedBox(height: 430, child: Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Send Gift to Moment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      Expanded(child: gifts.when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('$e')), data: (list) => GridView.count(crossAxisCount: 3, children: [
        for (final g in list) InkWell(onTap: () => setState(() => selected = g), child: Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.card_giftcard, size: 30, color: selected?.id == g.id ? Theme.of(context).colorScheme.primary : null),
          Text(g.name), Text('${g.price} coins', style: Theme.of(context).textTheme.bodySmall),
        ]))),
      ]))),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        for (final q in [1, 2, 5, 10]) Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text('$q'), selected: qty == q, onSelected: (_) => setState(() => qty = q))),
        const Spacer(),
        FilledButton(onPressed: busy || selected == null ? null : () async {
          setState(() => busy = true);
          try {
            await ref.read(momentRepositoryProvider).sendGift(momentId: widget.momentId, receiverId: widget.receiverId, giftId: selected!.id, qty: qty, key: 'moment-${DateTime.now().microsecondsSinceEpoch}-${selected!.id}');
            if (mounted) Navigator.pop(context);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
          finally { if (mounted) setState(() => busy = false); }
        }, child: const Text('Send Gift')),
      ])),
    ])));
  }
}
