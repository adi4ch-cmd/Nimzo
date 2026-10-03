import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'notification_repository.dart';

IconData _iconForNotification(String category) => switch (category.toLowerCase()) { 'messages' => Icons.chat_bubble_outline_rounded, 'gifts' => Icons.card_giftcard_rounded, 'followers' => Icons.person_add_alt_1_rounded, 'friends' => Icons.people_outline_rounded, 'rooms' => Icons.mic_external_on_rounded, 'vip' => Icons.workspace_premium_rounded, 'svip' => Icons.diamond_rounded, _ => Icons.notifications_none_rounded };

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: notificationCategories.length,
        child: Scaffold(
          appBar: AppBar(title: const Text('Notifications'), actions: [IconButton(tooltip: 'Mark all read', icon: const Icon(Icons.done_all_rounded), onPressed: () { context; })], bottom: TabBar(isScrollable: true, tabs: [for (final c in notificationCategories) Tab(text: c)])),
          body: TabBarView(children: [for (final c in notificationCategories) _List(c)]),
        ),
      );
}

class _List extends ConsumerWidget {
  final String cat;
  const _List(this.cat);
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(notificationsProvider(cat)).when(
        loading: () => const ShimmerView(rows: 5),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(notificationsProvider(cat))),
        data: (l) => l.isEmpty ? const EmptyView(title: 'Nothing here yet') : ListView.separated(padding: const EdgeInsets.symmetric(vertical: 8), separatorBuilder: (_, __) => const Divider(height: 1), itemCount: l.length, itemBuilder: (_, i) { final n = l[i]; final unread = n['read_at'] == null; return ListTile(leading: CircleAvatar(child: Icon(_iconForNotification(cat))), title: Text(n['title'] ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)), subtitle: Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis), trailing: unread ? const Icon(Icons.circle, size: 9) : null); }),
      );
}
