import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/reference_widgets.dart';
import 'notification_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NoticeState();
}

class _NoticeState extends ConsumerState<NotificationsScreen> {
  String category = 'All';
  bool marking = false;
  Future<void> markRead() async {
    if (marking) return;
    final repository = ref.read(notificationRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => marking = true);
    try {
      await repository.markAllRead();
      for (final c in notificationCategories) {
        container.invalidate(notificationsProvider(c));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notifications could not be marked read. Retry.')));
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          IconButton(
              tooltip: 'Mark all read',
              onPressed: marking ? null : markRead,
              icon: const Icon(Icons.done_all)),
        ]),
        body: Column(children: [
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                for (final c in notificationCategories)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(c),
                          selected: c == category,
                          onSelected: (_) => setState(() => category = c))),
              ])),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () async {
                    final selected = category;
                    ref.invalidate(notificationsProvider(selected));
                    await ref.read(notificationsProvider(selected).future);
                  },
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        AsyncContent(
                            value: ref.watch(notificationsProvider(category)),
                            onRetry: () =>
                                ref.invalidate(notificationsProvider(category)),
                            builder: (rows) => rows.isEmpty
                                ? const EmptyContent('No notifications yet')
                                : Column(children: [
                                    for (final r in rows)
                                      ListTile(
                                        title: Text(
                                            r['title']?.toString() ??
                                                r['category']?.toString() ??
                                                'Notification',
                                            style: TextStyle(
                                                fontWeight: r['read_at'] == null
                                                    ? FontWeight.w600
                                                    : FontWeight.normal)),
                                        subtitle:
                                            Text(r['body']?.toString() ?? ''),
                                      ),
                                  ])),
                      ]))),
        ]),
      );
}
