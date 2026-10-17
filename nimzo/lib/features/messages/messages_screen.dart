import '../../core/widgets/master_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import 'message_repository.dart';
import '../social/social_repositories.dart';
import '../social/blocked_users_screen.dart';
import '../profile/profile_repository.dart';

/// Reference-like Inbox using the existing conversation_list RPC and RLS.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});
  @override
  ConsumerState<MessagesScreen> createState() => _InboxState();
}

class _InboxState extends ConsumerState<MessagesScreen> {
  final search = TextEditingController();
  int selection = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xfff5f4ff),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text('Messages', style: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w900,
          color: Color(0xff23183b))),
        actions: [
          IconButton(
            tooltip: 'Friends',
            onPressed: () => context.push('/friends'),
            icon: const Icon(Icons.people_outline_rounded,
              color: NimzoStyle.primary),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded,
              color: NimzoStyle.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          await ref.read(conversationsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(15, 17, 15, 95),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff8753de), Color(0xffb179f6)],
                ),
                borderRadius: BorderRadius.circular(26)),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .19),
                    borderRadius: BorderRadius.circular(17)),
                  child: const Icon(Icons.forum_rounded,
                    color: Colors.white, size: 33)),
                const SizedBox(width: 13),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stay Connected',
                      style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 19)),
                    SizedBox(height: 5),
                    Text('Private chats with your NIMZO friends',
                      style: TextStyle(color: Color(0xfff3e7ff),
                        fontSize: 12)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: NimzoStyle.line)),
              child: TextField(
                key: const ValueKey('inbox-search'),
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded,
                    color: NimzoStyle.primary),
                  hintText: 'Search conversations',
                  hintStyle: const TextStyle(
                    color: Color(0xff9a90af)),
                  suffixIcon: search.text.isEmpty ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(search.clear),
                        icon: const Icon(Icons.close_rounded)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                for (var index = 0; index < 2; index++)
                  Expanded(child: InkWell(
                    key: ValueKey('inbox-tab-$index'),
                    onTap: () => setState(() => selection = index),
                    borderRadius: BorderRadius.circular(17),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selection == index
                          ? NimzoStyle.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(17)),
                      child: Text(index == 0 ? 'All Chats' : 'Unread',
                        style: TextStyle(
                          color: selection == index
                            ? Colors.white : const Color(0xff8d809e),
                          fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  )),
              ]),
            ),
            const SizedBox(height: 12),
            conversations.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator())),
              error: (_, __) => Column(children: [
                const Text('Unable to load conversations'),
                TextButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('Retry')),
              ]),
              data: (rows) {
                final term = search.text.trim().toLowerCase();
                final visible = rows.where((item) {
                  final unread = int.tryParse(
                    item['unread']?.toString() ?? '') ?? 0;
                  if (selection == 1 && unread <= 0) return false;
                  if (term.isEmpty) return true;
                  return [
                    item['display_name'], item['username'],
                    item['last_body'],
                  ].any((v) => (v?.toString() ?? '')
                      .toLowerCase().contains(term));
                }).toList();
                if (visible.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(15, 45, 15, 45),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22)),
                    child: Column(children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                        color: Color(0xffb2a3d7), size: 52),
                      const SizedBox(height: 13),
                      Text(
                        term.isNotEmpty ? 'No matching conversations'
                          : selection == 1 ? 'No unread messages'
                          : 'No conversations yet',
                        style: const TextStyle(
                          color: Color(0xff857695),
                          fontWeight: FontWeight.w700)),
                      if (selection == 0 && term.isEmpty) TextButton.icon(
                        onPressed: () => context.push('/discover'),
                        icon: const Icon(Icons.search),
                        label: const Text('Discover people')),
                    ]),
                  );
                }
                return Column(children: [
                  for (final row in visible) ConversationTile(row: row),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
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
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NimzoStyle.line),
      ),
      child: ListTile(
      leading: NimzoAvatar(
        name: name,
        url: profile?.avatarPath == null
            ? null
            : ref
                .watch(supabaseProvider)
                .storage
                .from('avatars')
                .getPublicUrl(profile!.avatarPath!),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        row['last_body']?.toString() ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unread > 0
          ? Semantics(
              label: '$unread unread messages',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: NimzoStyle.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            )
          : null,
      onTap: () => context.push('/chat/$id'),
      ),
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
  bool busy = false, reading = false, blockBusy = false;
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

  Future<void> toggleBlock() async {
    if (blockBusy) return;
    setState(() => blockBusy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final ids = await ref.read(blockedUserIdsProvider.future);
      final repository = ref.read(blockRepositoryProvider);
      if (ids.contains(widget.otherId)) {
        await repository.unblock(widget.otherId);
      } else {
        await repository.block(widget.otherId);
      }
      container.invalidate(blockedUserIdsProvider);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update blocking. Retry.')),
        );
    } finally {
      if (mounted) setState(() => blockBusy = false);
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
        actions: [
          PopupMenuButton<String>(
            enabled: !blockBusy,
            onSelected: (_) => toggleBlock(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Text(
                  ref
                              .watch(blockedUserIdsProvider)
                              .valueOrNull
                              ?.contains(widget.otherId) ==
                          true
                      ? 'Unblock user'
                      : 'Block user',
                ),
              ),
            ],
          ),
        ],
        title: InkWell(
          onTap: () => context.push('/profile/${widget.otherId}'),
          child: Row(
            children: [
              NimzoAvatar(
                name: other?.displayName ?? 'N',
                size: 36,
                url: avatar == null
                    ? null
                    : ref
                        .watch(supabaseProvider)
                        .storage
                        .from('avatars')
                        .getPublicUrl(avatar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  other?.displayName ?? other?.username ?? 'Conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
                            horizontal: 11,
                            vertical: 7,
                          ),
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
                              Text(
                                m.body ?? '',
                                style: TextStyle(
                                  color: m.senderId == me
                                      ? Colors.white
                                      : NimzoStyle.ink,
                                ),
                              ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                        gradient: NimzoStyle.gradient,
                      ),
                      child: const ReferenceIcon('send', color: Colors.white),
                    ),
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
