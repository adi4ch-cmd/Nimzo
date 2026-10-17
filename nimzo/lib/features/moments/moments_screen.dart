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

final followedMomentsAuthorsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return <String>{};
  final rows = await ref.watch(sessionSupabaseProvider).client
      .from('follows').select('followee_id')
      .eq('follower_id', me).limit(300);
  return rows.map((row) => row['followee_id'].toString()).toSet();
});

/// Reference-style Moments feed, retaining the real MomentCard actions.
class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({super.key});
  @override
  ConsumerState<MomentsScreen> createState() => _MomentsState();
}

class _MomentsState extends ConsumerState<MomentsScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final moments = ref.watch(momentsFeedProvider);
    final following = ref.watch(followedMomentsAuthorsProvider);
    return Scaffold(
      backgroundColor: const Color(0xfff6f5ff),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Moments', style: TextStyle(
          color: Color(0xff302349), fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Create moment',
            onPressed: () => context.push('/moments/create'),
            icon: const Icon(Icons.add_box_outlined,
              color: NimzoStyle.primary, size: 27),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(momentsFeedProvider);
          ref.invalidate(followedMomentsAuthorsProvider);
          await ref.read(momentsFeedProvider.future);
          if (selected == 1) {
            await ref.read(followedMomentsAuthorsProvider.future);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 96),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                boxShadow: const [
                  BoxShadow(color: Color(0x0f6740bb), blurRadius: 12),
                ],
              ),
              child: Row(children: [
                for (var tab = 0; tab < 2; tab++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => selected = tab),
                      borderRadius: BorderRadius.circular(21),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: selected == tab
                            ? const LinearGradient(colors: [
                                Color(0xffa248f7), Color(0xff7641dd),
                              ])
                            : null,
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Text(
                          tab == 0 ? 'Discover' : 'Following',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: selected == tab ? Colors.white
                              : const Color(0xff82769e),
                            fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            moments.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator())),
              error: (_, __) => Column(
                children: [
                  const Text('Moments could not be loaded'),
                  TextButton(
                    onPressed: () => ref.invalidate(momentsFeedProvider),
                    child: const Text('Retry')),
                ],
              ),
              data: (all) {
                if (selected == 1 && following.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(35),
                    child: Center(child: CircularProgressIndicator()));
                }
                if (selected == 1 && following.hasError) {
                  return Column(children: [
                    const Text('Following list unavailable'),
                    TextButton(
                      onPressed: () =>
                        ref.invalidate(followedMomentsAuthorsProvider),
                      child: const Text('Retry')),
                  ]);
                }
                final authors = following.valueOrNull ?? <String>{};
                final visible = selected == 0
                    ? all
                    : all.where((m) => authors.contains(m.authorId)).toList();
                if (visible.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 55, horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23)),
                    child: Column(children: [
                      const Icon(Icons.auto_awesome_outlined,
                        size: 56, color: Color(0xffb09cda)),
                      const SizedBox(height: 12),
                      Text(selected == 0 ? 'No Moments yet'
                        : 'Nothing from people you follow',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xff716687))),
                      if (selected == 0) TextButton(
                        onPressed: () => context.push('/moments/create'),
                        child: const Text('Share a moment')),
                    ]),
                  );
                }
                return Column(children: [
                  for (final moment in visible) MomentCard(moment: moment),
                ]);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('moments-post-button'),
        backgroundColor: const Color(0xff9b3de5),
        foregroundColor: Colors.white,
        onPressed: () => context.push('/moments/create'),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Post'),
      ),
    );
  }
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
        border: Border.all(color: NimzoStyle.line),
        boxShadow: const [BoxShadow(
          color: Color(0x176628cf), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
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
        backgroundColor: const Color(0xfff5f2ff),
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          foregroundColor: const Color(0xff332347),
          title: Text(widget.id == null ? 'New moment' : 'Edit Moment',
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900)),
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(17, 20, 17, 36),
                    children: [
                       Container(
                         padding: const EdgeInsets.all(16),
                         margin: const EdgeInsets.only(bottom: 14),
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(
                             colors: [
                               Color(0xff6638b5),
                               Color(0xffa44ce4),
                               Color(0xffe67dc7),
                             ],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           ),
                           borderRadius: BorderRadius.circular(25),
                         ),
                         child: const Row(children: [
                           Icon(Icons.auto_awesome_outlined,
                             color: Color(0xffffd87e), size: 34),
                           SizedBox(width: 12),
                           Expanded(child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('Share your story',
                                 style: TextStyle(color: Colors.white,
                                   fontWeight: FontWeight.w900, fontSize: 20)),
                               SizedBox(height: 3),
                               Text('Photos and words for your NIMZO community',
                                 style: TextStyle(color: Color(0xfff5eaff),
                                   fontSize: 12)),
                             ],
                           )),
                         ]),
                       ),
                      TextField(
                        controller: text,
                        maxLength: 2000,
                        minLines: 5,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Share your story with friends…',
                          hintStyle: TextStyle(
                            color: Color(0xffa99dbb),
                            fontSize: 16),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.fromLTRB(
                            19, 22, 19, 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(24)),
                            borderSide: BorderSide(
                              color: Color(0xffe5dff2))),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(24)),
                            borderSide: BorderSide(
                              color: NimzoStyle.primary, width: 1.8)),
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text('Photo',
                        style: TextStyle(
                          color: Color(0xff3b2a52),
                          fontWeight: FontWeight.w900,
                          fontSize: 17)),
                      const SizedBox(height: 10),
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
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: NimzoStyle.primary,
                          side: const BorderSide(
                            color: Color(0xffdfd4ed)),
                          minimumSize: const Size.fromHeight(75),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23))),
                        label: Text(image == null
                          ? 'Choose photo'
                          : 'Replace photo',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                      ),
                      if (image != null) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ref
                                .watch(supabaseProvider)
                                .storage
                                .from('moments')
                                .getPublicUrl(image!),
                            height: 230,
                            width: double.infinity,
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
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: NimzoStyle.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(67),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
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
