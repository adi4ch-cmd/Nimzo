import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/services/storage_service.dart';
import '../profile/profile_repository.dart';
import 'moment_repository.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Moments'),
          actions: [
            IconButton(
              onPressed: () => context.push('/moments/create'),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(momentsFeedProvider);
            await ref.read(momentsFeedProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AsyncContent(
                value: ref.watch(momentsFeedProvider),
                onRetry: () => ref.invalidate(momentsFeedProvider),
                builder: (p) => p.isEmpty
                    ? const EmptyContent('No Moments yet')
                    : Column(
                        children: [for (final m in p) MomentCard(moment: m)]),
              ),
            ],
          ),
        ),
      );
}

class MomentCard extends ConsumerWidget {
  final Moment moment;
  const MomentCard({super.key, required this.moment});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(profileProvider(moment.authorId)).valueOrNull;
    return ReferenceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: NimzoAvatar(name: author?.displayName ?? 'N'),
            title: Text(author?.displayName ?? 'Nimzo user'),
            subtitle: Text(
              moment.createdAt.toLocal().toString().split('.').first,
            ),
            onTap: () => context.push('/profile/${moment.authorId}'),
          ),
          if (moment.text != null) Text(moment.text!),
          if (moment.imagePath != null)
            Image.network(
              ref
                  .watch(supabaseProvider)
                  .storage
                  .from('moments')
                  .getPublicUrl(moment.imagePath!),
              errorBuilder: (_, __, ___) =>
                  const EmptyContent('Image unavailable'),
            ),
          Wrap(
            children: [
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(momentRepositoryProvider)
                        .toggleLike(moment.id);
                    ref.invalidate(momentsFeedProvider);
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unable to update like.')),
                      );
                  }
                },
                child: Text('${moment.likes} likes'),
              ),
              TextButton(
                onPressed: () => context.push('/moments/${moment.id}'),
                child: Text('${moment.comments} comments'),
              ),
              if (ref.watch(currentUserIdProvider) == moment.authorId)
                TextButton(
                  onPressed: () => context.push('/moments/${moment.id}/edit'),
                  child: const Text('Edit'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CreateMomentScreen extends ConsumerStatefulWidget {
  final String? id;
  const CreateMomentScreen({super.key, this.id});
  @override
  ConsumerState<CreateMomentScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<CreateMomentScreen> {
  final text = TextEditingController();
  String? image;
  bool busy = false, ready = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (widget.id != null) {
        try {
          final m = await ref.read(momentRepositoryProvider).get(widget.id!);
          if (!mounted) return;
          text.text = m.text ?? '';
          image = m.imagePath;
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to load Moment.')),
            );
          return;
        }
      }
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'Create Moment' : 'Edit Moment'),
        ),
        body: !ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: text,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration:
                        const InputDecoration(hintText: 'Share a Moment'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              final path = await ref
                                  .read(storageServiceProvider)
                                  .pickAndUpload('moments');
                              if (path != null && mounted)
                                setState(() => image = path);
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Image could not be uploaded.'),
                                  ),
                                );
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child:
                        Text(image == null ? 'Choose photo' : 'Replace photo'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (text.text.trim().isEmpty && image == null)
                              return;
                            setState(() => busy = true);
                            try {
                              final r = ref.read(momentRepositoryProvider);
                              if (widget.id == null) {
                                await r.create(
                                  text: text.text.trim(),
                                  imagePath: image,
                                );
                              } else {
                                await r.update(
                                  widget.id!,
                                  text: text.text.trim(),
                                  imagePath: image,
                                );
                              }
                              ref.invalidate(momentsFeedProvider);
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Moment could not be saved.'),
                                  ),
                                );
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: const Text('Save'),
                  ),
                ],
              ),
      );
}

final momentDetailProvider = FutureProvider.family<Moment, String>(
  (ref, id) => ref.watch(momentRepositoryProvider).get(id),
);

class MomentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const MomentDetailScreen({super.key, required this.id});
  @override
  ConsumerState<MomentDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<MomentDetailScreen> {
  final comment = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moment')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AsyncContent(
              value: ref.watch(momentDetailProvider(widget.id)),
              onRetry: () => ref.invalidate(momentDetailProvider(widget.id)),
              builder: (m) => MomentCard(moment: m),
            ),
            AsyncContent(
              value: ref.watch(commentsProvider(widget.id)),
              onRetry: () => ref.invalidate(commentsProvider(widget.id)),
              builder: (rows) => Column(
                children: [
                  for (final c in rows)
                    ListTile(title: Text(c['body']?.toString() ?? '')),
                ],
              ),
            ),
            TextField(
              controller: comment,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (comment.text.trim().isEmpty) return;
                      setState(() => busy = true);
                      try {
                        await ref
                            .read(momentRepositoryProvider)
                            .addComment(widget.id, comment.text.trim());
                        comment.clear();
                        ref.invalidate(commentsProvider(widget.id));
                        ref.invalidate(momentDetailProvider(widget.id));
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Comment could not be sent.'),
                            ),
                          );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Send'),
            ),
          ],
        ),
      );
}
