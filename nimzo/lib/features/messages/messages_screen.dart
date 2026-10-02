import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/nimzo_avatar.dart';
import '../../core/widgets/shimmer_view.dart';
import '../profile/profile_repository.dart';
import 'message_repository.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});
  @override
  ConsumerState<MessagesScreen> createState() => _M();
}

class _M extends ConsumerState<MessagesScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Messages'), actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () => context.push('/notifications')),
        ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(hintText: 'Search users or Nimzo ID', prefixIcon: Icon(Icons.search)))),
          Expanded(child: q.isNotEmpty ? _Search(q) : ref.watch(conversationsProvider).when(
            loading: () => const ShimmerView(),
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(conversationsProvider)),
            data: (l) => l.isEmpty
                ? const EmptyView(title: 'No conversations', hint: 'Start a chat from a profile.')
                : ListView(children: [
                    for (final c in l)
                      ListTile(
                        leading: const NimzoAvatar(),
                        title: Text(c['display_name'] ?? 'User'),
                        subtitle: Text(c['last_body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(timeAgo(DateTime.parse(c['last_at']))),
                          if ((c['unread'] ?? 0) > 0) CircleAvatar(radius: 9, child: Text('${c['unread']}', style: const TextStyle(fontSize: 10))),
                        ]),
                        onTap: () => context.push('/chat/${c['other_id']}'),
                      ),
                  ]),
          )),
        ]),
      );
}

class _Search extends ConsumerWidget {
  final String q;
  const _Search(this.q);
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
        future: ref.read(profileRepositoryProvider).search(q),
        builder: (_, s) => s.connectionState != ConnectionState.done
            ? const ShimmerView(rows: 3)
            : s.hasError
                ? ErrorView(message: '${s.error}', onRetry: () {})
                : ListView(children: [for (final u in s.data!) ListTile(leading: const NimzoAvatar(), title: Text(u.displayName ?? 'User'), subtitle: Text('ID ${u.nimzoId}'), onTap: () => context.push('/profile/${u.id}'))]),
      );
}

class ConversationScreen extends ConsumerStatefulWidget {
  final String otherId;
  const ConversationScreen({super.key, required this.otherId});
  @override
  ConsumerState<ConversationScreen> createState() => _C();
}

class _C extends ConsumerState<ConversationScreen> {
  final _t = TextEditingController();
  RealtimeChannel? _typing;
  bool _otherTyping = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(messageRepositoryProvider).markRead(widget.otherId));
    _typing = ref.read(messageRepositoryProvider).typingChannel(widget.otherId)
      ..onBroadcast(event: 'typing', callback: (p) {
        if (p['from'] == widget.otherId && mounted) {
          setState(() => _otherTyping = true);
          Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _otherTyping = false); });
        }
      })
      ..subscribe();
  }
  @override
  void dispose() { _t.dispose(); _typing?.unsubscribe(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_otherTyping ? 'Typing…' : 'Chat')),
      body: Column(children: [
        Expanded(child: ref.watch(chatProvider(widget.otherId)).when(
          loading: () => const ShimmerView(rows: 4),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(chatProvider(widget.otherId))),
          data: (l) => l.isEmpty ? const EmptyView(title: 'Say hi') : ListView(reverse: true, padding: const EdgeInsets.all(12), children: [
            for (final m in l.reversed)
              Align(
                alignment: m.senderId == me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: m.senderId == me ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(m.body ?? ''),
                    if (m.senderId == me) Icon(m.read ? Icons.done_all : Icons.done, size: 12),
                  ]),
                ),
              ),
          ]),
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _t, onChanged: (_) => _typing?.sendBroadcastMessage(event: 'typing', payload: {'from': me}), decoration: const InputDecoration(hintText: 'Message'))),
          IconButton(icon: const Icon(Icons.send), onPressed: () async {
            final s = _t.text.trim();
            if (s.isEmpty) return;
            _t.clear();
            try { await ref.read(messageRepositoryProvider).send(widget.otherId, s); }
            catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
          }),
        ]))),
      ]),
    );
  }
}
