import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/helpers.dart';
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
                      leading: m.imagePath == null
                          ? null
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                storageUrl(ref.read(supabaseProvider), 'moment-images', m.imagePath),
                                width: 58, height: 58, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      title: Text(m.text ?? (m.imagePath != null ? 'Photo' : '')),
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
                          if (v == 'edit') {
                            await context.push('/moments/' + m.id + '/edit');
                            ref.invalidate(momentsFeedProvider);
                          } else {
                            if (v == 'delete') await repo.delete(m.id); else await repo.report(m.id, 'user_report');
                            ref.invalidate(momentsFeedProvider);
                          }
                        },
                        itemBuilder: (_) => [
                          if (m.authorId == me) const PopupMenuItem(value: 'edit', child: Text('Edit')),
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
  final String? id;
  const CreateMomentScreen({super.key, this.id});
  @override ConsumerState<CreateMomentScreen> createState() => _C();
}

class _C extends ConsumerState<CreateMomentScreen> {
  final _t = TextEditingController();
  bool busy = false;
  String? _imagePath;
  File? _localImage;

  @override void initState() {
    super.initState();
    if (widget.id != null) {
      ref.read(momentRepositoryProvider).get(widget.id!).then((m) {
        if (!mounted) return;
        setState(() { _t.text = m.text ?? ''; _imagePath = m.imagePath; });
      }).catchError((e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      });
    }
  }

  @override void dispose() { _t.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
      if (x == null) return;
      setState(() => _localImage = File(x.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo selection failed: $e')));
    }
  }

  Future<void> _save() async {
    final text = _t.text.trim();
    if (text.isEmpty && _localImage == null && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add text or a photo.')));
      return;
    }
    setState(() => busy = true);
    try {
      String? path = _imagePath;
      if (_localImage != null) {
        final db = ref.read(supabaseProvider);
        final uid = db.auth.currentUser!.id;
        path = uid + '/' + DateTime.now().microsecondsSinceEpoch.toString() + '.jpg';
        await db.storage.from('moment-images').upload(path, _localImage!, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      }
      final repo = ref.read(momentRepositoryProvider);
      if (widget.id == null) {
        await repo.create(text: text.isEmpty ? null : text, imagePath: path);
      } else {
        await repo.update(widget.id!, text: text.isEmpty ? null : text, imagePath: path);
      }
      ref.invalidate(momentsFeedProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save moment: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'New moment' : 'Edit moment'),
      actions: [TextButton(onPressed: busy ? null : _save, child: Text(widget.id == null ? 'Post' : 'Save'))],
    ),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (_localImage != null || _imagePath != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _localImage != null
              ? Image.file(_localImage!, height: 260, fit: BoxFit.cover)
              : Image.network(storageUrl(ref.read(supabaseProvider), 'moment-images', _imagePath), height: 260, fit: BoxFit.cover),
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: busy ? null : _pickImage, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose photo from phone')),
      const SizedBox(height: 10),
      TextField(controller: _t, maxLines: null, maxLength: 500, decoration: const InputDecoration(hintText: 'What is on your mind?')),
    ]),
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
