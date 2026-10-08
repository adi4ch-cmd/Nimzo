import '../../core/widgets/master_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import 'message_repository.dart';
import '../profile/profile_repository.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const GradientText('Messages')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
            await ref.read(conversationsProvider.future);
          },
          child: ListView(
            children: [
              AsyncContent(
                value: ref.watch(conversationsProvider),
                onRetry: () => ref.invalidate(conversationsProvider),
                builder: (rows) => rows.isEmpty
                    ? const EmptyContent('No conversations yet')
                    : Column(
                        children: [
                          for (final r in rows) ConversationTile(row: r),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
}

class ConversationTile extends ConsumerWidget {
  final Map<String, dynamic> row;
  const ConversationTile({super.key, required this.row});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row['other_id']?.toString();
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final profile = ref.watch(profileProvider(id)).valueOrNull;
    final name = profile?.displayName ??
        profile?.username ??
        row['display_name']?.toString() ??
        row['username']?.toString() ??
        'Nimzo user';
    final unread = int.tryParse(row['unread']?.toString() ?? '') ?? 0;
    return ListTile(
      leading: NimzoAvatar(
          name: name,
          url: profile?.avatarPath == null
              ? null
              : ref
                  .watch(supabaseProvider)
                  .storage
                  .from('avatars')
                  .getPublicUrl(profile!.avatarPath!)),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(row['last_body']?.toString() ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: unread > 0
          ? Semantics(
              label: '$unread unread messages',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: NimzoStyle.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ))
          : null,
      onTap: () => context.push('/chat/$id'),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  final String otherId;
  const ConversationScreen({super.key, required this.otherId});
  @override
  ConsumerState<ConversationScreen> createState() => _State();
}

class _State extends ConsumerState<ConversationScreen> {
  final body = TextEditingController();
  bool busy = false, reading = false;
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || body.text.trim().isEmpty) return;
    final submitted = body.text;
    setState(() => busy = true);
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final repository = ref.read(messageRepositoryProvider);
      await repository.send(widget.otherId, submitted.trim());
      container.invalidate(conversationsProvider);
      if (mounted && body.text == submitted) body.clear();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Retry.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final other = ref.watch(profileProvider(widget.otherId)).valueOrNull;
    final avatar = other?.avatarPath;
    ref.listen(chatProvider(widget.otherId), (_, next) {
      final unread =
          next.valueOrNull?.any((m) => m.receiverId == me && !m.read) ?? false;
      if (unread && !reading) {
        reading = true;
        final container = ProviderScope.containerOf(context, listen: false);
        ref
            .read(messageRepositoryProvider)
            .markRead(widget.otherId)
            .then((_) {
              container.invalidate(conversationsProvider);
            })
            .catchError((Object _) {})
            .whenComplete(() => reading = false);
      }
    });
    return Scaffold(
      appBar: AppBar(
          title: InkWell(
        onTap: () => context.push('/profile/${widget.otherId}'),
        child: Row(children: [
          NimzoAvatar(
              name: other?.displayName ?? 'N',
              size: 36,
              url: avatar == null
                  ? null
                  : ref
                      .watch(supabaseProvider)
                      .storage
                      .from('avatars')
                      .getPublicUrl(avatar)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  other?.displayName ?? other?.username ?? 'Conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      )),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AsyncContent(
                value: ref.watch(chatProvider(widget.otherId)),
                onRetry: () => ref.invalidate(chatProvider(widget.otherId)),
                builder: (messages) => ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final m in messages.reversed)
                      Align(
                        alignment: m.senderId == me
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .8,
                          ),
                          decoration: BoxDecoration(
                            color: m.senderId == me ? null : NimzoStyle.surface,
                            gradient:
                                m.senderId == me ? NimzoStyle.gradient : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body ?? '',
                                  style: TextStyle(
                                      color: m.senderId == me
                                          ? Colors.white
                                          : NimzoStyle.ink)),
                              Text(
                                '${m.createdAt.toLocal().hour}:${m.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: m.senderId == me
                                      ? Colors.white70
                                      : NimzoStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: body,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : send,
                    tooltip: 'Send',
                    icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: NimzoStyle.gradient),
                        child:
                            const ReferenceIcon('send', color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
