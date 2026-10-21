import '../../core/widgets/master_ui.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tingle_surface.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/services/storage_service.dart';
import '../profile/profile_repository.dart';
import '../gifts/gift_sheet.dart';
import 'moment_repository.dart';

final followedMomentsAuthorsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return <String>{};
  final rows = await ref
      .watch(sessionSupabaseProvider)
      .client
      .from('follows')
      .select('followee_id')
      .eq('follower_id', me)
      .limit(300);
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
      backgroundColor: const Color(0xfff5faf7),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: tingleSky),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
            child: Row(children: [
              Expanded(
                  child: TingleTabs(
                      labels: const ['Square', 'Follow'],
                      selected: selected,
                      light: true,
                      onSelected: (value) => setState(() => selected = value))),
              IconButton(
                  tooltip: 'Search people',
                  onPressed: () => context.push('/discover'),
                  icon: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 22)),
              IconButton(
                  key: const ValueKey('moments-post-button'),
                  tooltip: 'Create moment',
                  onPressed: () => context.push('/moments/create'),
                  icon: const Icon(Icons.add_box_outlined,
                      color: Colors.white, size: 22)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Moments',
                    style: TextStyle(
                        color: Color(0xff087f5b),
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
          ),
          Expanded(
              child: RefreshIndicator(
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
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
              children: [
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
                        : all
                            .where((m) => authors.contains(m.authorId))
                            .toList();
                    if (visible.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 55, horizontal: 18),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(23)),
                        child: Column(children: [
                          const NimzoIdentityArt(
                              kind: NimzoArt.mascot,
                              size: 88,
                              color: Color(0xffb09cda)),
                          const SizedBox(height: 12),
                          Text(
                              selected == 0
                                  ? 'No Moments yet'
                                  : 'Nothing from people you follow',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff716687))),
                          if (selected == 0)
                            TextButton(
                                onPressed: () =>
                                    context.push('/moments/create'),
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
          )),
        ]),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NimzoStyle.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x176628cf), blurRadius: 12, offset: Offset(0, 3))
        ],
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
            if (moment.imagePaths.isNotEmpty)
              SizedBox(
                height: moment.imagePaths.length > 1 ? 240 : null,
                child: moment.imagePaths.length == 1
                    ? _momentImage(ref, moment.imagePaths.first)
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: moment.imagePaths.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) => SizedBox(
                            width: 240,
                            child: _momentImage(ref, moment.imagePaths[i])),
                      ),
              ),
            if (moment.imagePaths.length > 1)
              Text('${moment.imagePaths.length} photos · Swipe to view',
                  style: const TextStyle(fontSize: 11)),
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
                        color:
                            moment.liked ? NimzoStyle.pink : NimzoStyle.muted,
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
                      Icon(Icons.directions_car_rounded, size: 18),
                      SizedBox(width: 5),
                      Text('Car'),
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
  List<String> images = [];
  String? get image => images.isEmpty ? null : images.first;
  bool busy = false, ready = false;
  bool loadFailed = false;
  bool get canPost => image != null || text.text.trim().isNotEmpty;

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    text.addListener(_draftChanged);
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
        images = List.of(m.imagePaths);
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => loadFailed = true);
    }
  }

  @override
  void dispose() {
    text.removeListener(_draftChanged);
    text.dispose();
    super.dispose();
  }

  Future<void> _saveMoment() async {
    if (!mounted ||
        !ready ||
        busy ||
        (text.text.trim().isEmpty && image == null)) return;

    // Capture providers and the container before the await. A successful
    // network save must still refresh feeds if the editor gets dismissed.
    final repository = ref.read(momentRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final id = widget.id;
    final body = text.text.trim();
    final photos = List<String>.of(images);
    final photo = image;
    String? authorId = ref.read(currentUserIdProvider);

    setState(() => busy = true);
    try {
      if (id == null) {
        await repository.create(
            text: body, imagePath: photo, imagePaths: photos);
      } else {
        authorId ??= (await repository.get(id)).authorId;
        await repository.update(id,
            text: body, imagePath: photo, imagePaths: photos);
        container.invalidate(momentDetailProvider(id));
      }
      container.invalidate(momentsFeedProvider);
      if (authorId != null) {
        container.invalidate(profileMomentsProvider(authorId));
        container.invalidate(profileStatsProvider(authorId));
      }
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moment could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          foregroundColor: const Color(0xff332347),
          title: Text(widget.id == null ? 'Post Moments' : 'Edit Moment',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          actions: [
            TextButton(
              key: const ValueKey('moment-top-post'),
              onPressed: busy || !ready || !canPost ? null : _saveMoment,
              child: Text(widget.id == null ? 'Post' : 'Save',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: busy || !ready || !canPost
                          ? const Color(0xffaaa5bc)
                          : NimzoStyle.primary)),
            ),
          ],
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
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                    children: [
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: 'Add photo (${images.length}/9)',
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: OutlinedButton(
                              key: const ValueKey('moment-photo-picker'),
                              onPressed: busy || images.length >= 9
                                  ? null
                                  : () async {
                                      final source = await showModalBottomSheet<
                                          ImageSource>(
                                        context: context,
                                        builder: (c) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons
                                                    .photo_library_outlined),
                                                title: const Text(
                                                    'Choose from gallery'),
                                                onTap: () => Navigator.pop(
                                                    c, ImageSource.gallery),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.camera_alt_outlined),
                                                title:
                                                    const Text('Take a photo'),
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
                                            .pickAndUpload('moments',
                                                source: source);
                                        if (path != null && mounted)
                                          setState(() => images.add(path));
                                      } catch (_) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Image could not be uploaded.'),
                                            ),
                                          );
                                      } finally {
                                        if (mounted)
                                          setState(() => busy = false);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: const Color(0xfff2f4fb),
                                foregroundColor: const Color(0xff9d99b0),
                                side:
                                    const BorderSide(color: Color(0xffe5e9f4)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Icon(Icons.add_rounded, size: 28),
                            ),
                          ),
                        ),
                      ),
                      if (images.isNotEmpty)
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final path in images)
                            SizedBox(
                                width: 88,
                                child: Column(children: [
                                  SizedBox(
                                      height: 88,
                                      child: _momentImage(ref, path)),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => images.remove(path)),
                                      child: const Text('Remove photo')),
                                ])),
                        ]),
                      TextField(
                        controller: text,
                        maxLength: 2000,
                        minLines: 5,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Say something to record this moment...',
                          hintStyle:
                              TextStyle(color: Color(0xff9b98a9), fontSize: 12),
                          filled: true,
                          fillColor: Color(0xfff2f4fb),
                          contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                          enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(color: Color(0xffe5dff2))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                  color: NimzoStyle.primary, width: 1.8)),
                        ),
                      ),
                      const SizedBox(height: 11),
                      InkWell(
                        key: const ValueKey('moment-mention-entry'),
                        onTap: () {
                          text.text = text.text.trimRight() + ' @';
                          text.selection =
                              TextSelection.collapsed(offset: text.text.length);
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          color: const Color(0xfff2f4fb),
                          child: const Row(children: [
                            Icon(Icons.alternate_email_rounded,
                                color: Color(0xff292332)),
                            SizedBox(width: 10),
                            Text('Mention',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                color: Color(0xff9a93b1)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text('#  Recommended topics',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          for (final topic in const [
                            '#Bookworm',
                            '#OpenMinded',
                            '#Photography',
                            '#KindHearted',
                            '#JustFriends',
                            '#LongTermOnly',
                            '#SeriousRelationship',
                            '#LookingForLove',
                          ])
                            ActionChip(
                              key: ValueKey('moment-topic-' + topic),
                              label: Text(topic,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xff79659c))),
                              backgroundColor: const Color(0xfff3efff),
                              side: BorderSide.none,
                              onPressed: () {
                                final current = text.text.trimRight();
                                text.text = current.isEmpty
                                    ? topic
                                    : current + ' ' + topic;
                                text.selection = TextSelection.collapsed(
                                    offset: text.text.length);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

Widget _momentImage(WidgetRef ref, String path) => Image.network(
      ref.watch(supabaseProvider).storage.from('moments').getPublicUrl(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const EmptyContent('Image unavailable'),
    );
