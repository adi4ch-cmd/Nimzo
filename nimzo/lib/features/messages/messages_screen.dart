import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import 'message_repository.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Messages')),
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
                          for (final r in rows)
                            ListTile(
                              leading: NimzoAvatar(
                                name: r['display_name']?.toString() ?? 'N',
                              ),
                              title: Text(
                                r['display_name']?.toString() ??
                                    r['username']?.toString() ??
                                    'Nimzo user',
                              ),
                              subtitle: Text(
                                r['last_body']?.toString() ?? '',
                                maxLines: 1,
                              ),
                              onTap: () =>
                                  context.push('/chat/${r['other_id']}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
}

class ConversationScreen extends ConsumerStatefulWidget {
  final String otherId;
  const ConversationScreen({super.key, required this.otherId});
  @override
  ConsumerState<ConversationScreen> createState() => _State();
}

class _State extends ConsumerState<ConversationScreen> {
  final body = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || body.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .send(widget.otherId, body.text.trim());
      body.clear();
      ref.invalidate(conversationsProvider);
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
    ref.listen(chatProvider(widget.otherId), (_, next) {
      if (next.hasValue)
        ref
            .read(messageRepositoryProvider)
            .markRead(widget.otherId)
            .catchError((_) {});
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
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
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .8,
                          ),
                          decoration: BoxDecoration(
                            color: NimzoStyle.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body ?? ''),
                              Text(
                                '${m.createdAt.toLocal().hour}:${m.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: NimzoStyle.muted,
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
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : send,
                    icon: const Icon(Icons.send),
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
