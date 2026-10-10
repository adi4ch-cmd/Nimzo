import '../../core/widgets/master_ui.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/services/storage_service.dart';
import '../profile/profile_repository.dart';
import '../gifts/gift_sheet.dart';
import '../gifts/yo2_gift_ui.dart';
import 'moment_repository.dart';

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const GradientText('Moments'),
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

class MomentCard extends ConsumerStatefulWidget {
  final Moment moment;
  final VoidCallback? onDeleted;
  const MomentCard({super.key, required this.moment, this.onDeleted});

  @override
  ConsumerState<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends ConsumerState<MomentCard> {
  bool _likeBusy = false;

  Moment get moment => widget.moment;

  @override
  Widget build(BuildContext context) {
    final author = ref.watch(profileProvider(moment.authorId)).valueOrNull;
    return Container(
      key: const ValueKey('premium-moment-card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe1eae4)),
        boxShadow: const [BoxShadow(
          color: Color(0x10051918), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 42,
            leading: NimzoAvatar(
              name: author?.displayName ?? 'N',
              url: author?.avatarPath == null
                  ? null
                  : ref
                      .watch(supabaseProvider)
                      .storage
                      .from('avatars')
                      .getPublicUrl(author!.avatarPath!),
            ),
            title: Tooltip(
              message: moment.createdAt.toLocal().toString().split('.').first,
              child: Text(author?.displayName ?? 'Nimzo user'),
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
                onPressed: _likeBusy
                    ? null
                    : () async {
                        final id = moment.id;
                        final authorId = moment.authorId;
                        final container = ProviderScope.containerOf(
                          context,
                          listen: false,
                        );
                        setState(() => _likeBusy = true);
                        try {
                          await ref
                              .read(momentRepositoryProvider)
                              .toggleLike(id);
                          container.invalidate(momentsFeedProvider);
                          container.invalidate(momentDetailProvider(id));
                          container.invalidate(
                            profileMomentsProvider(authorId),
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to update like.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _likeBusy = false);
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReferenceIcon(
                      moment.liked ? 'cp_filled' : 'cp',
                      size: 18,
                      color: moment.liked ? NimzoStyle.pink : NimzoStyle.muted,
                    ),
                    const SizedBox(width: 4),
                    Text('${moment.likes} likes'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showReferenceSheet(
                  context,
                  MomentDetailScreen(id: moment.id, sheet: true),
                ),
                child: Text('Comment ${moment.comments}'),
              ),
              TextButton(
                onPressed: () =>
                    showMomentGiftSheet(context, moment.id, moment.authorId),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Yo2GiftPanelArt(
                      'ic_moment_gift.webp',
                      width: 18,
                      height: 18,
                      fallback: Icon(Icons.card_giftcard, size: 17),
                    ),
                    SizedBox(width: 5),
                    Text('Gift'),
                  ],
                ),
              ),
              if (ref.watch(currentUserIdProvider) == moment.authorId)
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete this Moment?'),
                        content: const Text(
                          'This removes your post from Moments.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final container = ProviderScope.containerOf(
                      context,
                      listen: false,
                    );
                    final repo = ref.read(momentRepositoryProvider);
                    try {
                      await repo.delete(moment.id);
                      container.invalidate(momentsFeedProvider);
                      container.invalidate(
                        profileMomentsProvider(moment.authorId),
                      );
                      container.invalidate(
                        profileStatsProvider(moment.authorId),
                      );
                      container.invalidate(momentDetailProvider(moment.id));
                      if (context.mounted) widget.onDeleted?.call();
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Moment could not be deleted. Please retry.',
                            ),
                          ),
                        );
                    }
                  },
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
  bool loadFailed = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      ready = false;
      loadFailed = false;
    });
    final repository = ref.read(momentRepositoryProvider);
    try {
      if (widget.id != null) {
        final m = await repository.get(widget.id!);
        if (!mounted) return;
        text.text = m.text ?? '';
        image = m.imagePath;
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => loadFailed = true);
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.id == null ? 'New moment' : 'Edit Moment'),
        ),
        body: loadFailed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyContent('Unable to load Moment.'),
                    OutlinedButton(
                        onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            : !ready
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                       Container(
                         padding: const EdgeInsets.all(16),
                         margin: const EdgeInsets.only(bottom: 14),
                         decoration: BoxDecoration(
                           color: const Color(0xff12382d),
                           borderRadius: BorderRadius.circular(17),
                         ),
                         child: const Row(children: [
                           Icon(Icons.auto_awesome_outlined,
                             color: Color(0xffc6e6d5), size: 25),
                           SizedBox(width: 12),
                           Expanded(child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('Share your story',
                                 style: TextStyle(color: Colors.white,
                                   fontWeight: FontWeight.w800, fontSize: 17)),
                               SizedBox(height: 3),
                               Text('Photos and words for your NIMZO community',
                                 style: TextStyle(color: Color(0xffc0d5c8),
                                   fontSize: 12)),
                             ],
                           )),
                         ]),
                       ),
                      TextField(
                        controller: text,
                        maxLength: 2000,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Write a moment worth sharing…',
                          filled: true,
                          fillColor: Color(0xfff6faf7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(color: Color(0xffdae7dd))),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        onPressed: busy
                            ? null
                            : () async {
                                final source =
                                    await showModalBottomSheet<ImageSource>(
                                  context: context,
                                  builder: (c) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.photo_library_outlined),
                                          title: const Text('Choose from gallery'),
                                          onTap: () => Navigator.pop(
                                              c, ImageSource.gallery),
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_outlined),
                                          title: const Text('Take a photo'),
                                          onTap: () => Navigator.pop(
                                              c, ImageSource.camera),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (source == null || !mounted) return;
                                setState(() => busy = true);
                                try {
                                  final path = await ref
                                      .read(storageServiceProvider)
                                      .pickAndUpload('moments', source: source);
                                  if (path != null && mounted)
                                    setState(() => image = path);
                                } catch (_) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Image could not be uploaded.'),
                                      ),
                                    );
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        label: Text(
                            image == null ? 'Choose photo' : 'Replace photo'),
                      ),
                      if (image != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ref
                                .watch(supabaseProvider)
                                .storage
                                .from('moments')
                                .getPublicUrl(image!),
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const EmptyContent('Image unavailable'),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              busy ? null : () => setState(() => image = null),
                          child: const Text('Remove photo'),
                        ),
                      ],
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (text.text.trim().isEmpty && image == null)
                                  return;
                                setState(() => busy = true);
                                try {
                                  final r = ref.read(momentRepositoryProvider);
                                  final container = ProviderScope.containerOf(
                                    context,
                                    listen: false,
                                  );
                                  final id = widget.id;
                                  final body = text.text.trim();
                                  final photo = image;
                                  final currentUserId =
                                      ref.read(currentUserIdProvider);
                                  String? authorId = currentUserId;
                                  if (id == null) {
                                    await r.create(
                                        text: body, imagePath: photo);
                                  } else {
                                    authorId ??= (await r.get(id)).authorId;
                                    await r.update(id,
                                        text: body, imagePath: photo);
                                    container
                                        .invalidate(momentDetailProvider(id));
                                  }
                                  container.invalidate(momentsFeedProvider);
                                  if (authorId != null) {
                                    container.invalidate(
                                      profileMomentsProvider(authorId),
                                    );
                                    container.invalidate(
                                      profileStatsProvider(authorId),
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                } catch (_) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Moment could not be saved.'),
                                      ),
                                    );
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        child: Text(widget.id == null ? 'Publish moment' : 'Save changes'),
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
  final bool sheet;
  const MomentDetailScreen({super.key, required this.id, this.sheet = false});
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
  Widget build(BuildContext context) {
    final content = ListView(
      shrinkWrap: widget.sheet,
      physics: widget.sheet ? const NeverScrollableScrollPhysics() : null,
      padding: widget.sheet ? EdgeInsets.zero : const EdgeInsets.all(16),
      children: [
        if (!widget.sheet)
          AsyncContent(
            value: ref.watch(momentDetailProvider(widget.id)),
            onRetry: () => ref.invalidate(momentDetailProvider(widget.id)),
            builder: (m) => MomentCard(
              moment: m,
              onDeleted: () {
                if (Navigator.of(context).canPop()) Navigator.pop(context);
              },
            ),
          ),
        AsyncContent(
          value: ref.watch(commentsProvider(widget.id)),
          onRetry: () => ref.invalidate(commentsProvider(widget.id)),
          builder: (rows) => Column(
            children: [for (final c in rows) MomentCommentTile(comment: c)],
          ),
        ),
        TextField(
          controller: comment,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Add a comment…'),
        ),
        GradientButton(
          onPressed: busy
              ? null
              : () async {
                  if (comment.text.trim().isEmpty) return;
                  final submitted = comment.text;
                  final id = widget.id;
                  final authorId =
                      ref.read(momentDetailProvider(id)).valueOrNull?.authorId;
                  final repository = ref.read(momentRepositoryProvider);
                  final container = ProviderScope.containerOf(
                    context,
                    listen: false,
                  );
                  setState(() => busy = true);
                  try {
                    await repository.addComment(id, submitted.trim());
                    container.invalidate(commentsProvider(id));
                    container.invalidate(momentDetailProvider(id));
                    container.invalidate(momentsFeedProvider);
                    if (authorId != null) {
                      container.invalidate(profileMomentsProvider(authorId));
                    }
                    if (mounted && comment.text == submitted) comment.clear();
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
    );
    return widget.sheet
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content,
            ],
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Moment')),
            body: content,
          );
  }
}

class MomentCommentTile extends ConsumerWidget {
  final Map<String, dynamic> comment;
  const MomentCommentTile({super.key, required this.comment});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = comment['author_id'] as String?;
    final author =
        id == null ? null : ref.watch(profileProvider(id)).valueOrNull;
    return InkWell(
      onTap: id == null ? null : () => context.push('/profile/$id'),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .85,
          ),
          decoration: BoxDecoration(
            color: NimzoStyle.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author?.displayName ?? author?.username ?? 'Nimzo user',
                style: const TextStyle(
                  color: NimzoStyle.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(comment['body']?.toString() ?? ''),
            ],
          ),
        ),
      ),
    );
  }
}
