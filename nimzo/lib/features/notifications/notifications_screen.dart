import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'notification_repository.dart';

/// Server-sourced notification inbox with real category filters and
/// read-state. No generated counts or fake activities.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationState();
}

class _NotificationState extends ConsumerState<NotificationsScreen> {
  String category = 'All';
  bool marking = false;

  Future<void> markRead() async {
    if (marking) return;
    setState(() => marking = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      for (final tab in notificationCategories) {
        ref.invalidate(notificationsProvider(tab));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Could not mark notifications as read. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider(category));
    return Scaffold(
      backgroundColor: const Color(0xfff6f4ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Notifications',
          style: TextStyle(color: Color(0xff281d3e),
            fontSize: 21, fontWeight: FontWeight.w900)),
        actions: [
          TextButton.icon(
            onPressed: marking ? null : markRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(marking ? 'Wait…' : 'Read all'),
            style: TextButton.styleFrom(
              foregroundColor: NimzoStyle.primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider(category));
          await ref.read(notificationsProvider(category).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 85),
          children: [
            Container(
              height: 116,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff7443cb),
                    Color(0xffac58ea), Color(0xffd67be5)]),
                borderRadius: BorderRadius.circular(26)),
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 19),
              child: const Row(children: [
                Icon(Icons.notifications_active_outlined,
                  size: 54, color: Color(0xffffd4ff)),
                SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Stay Updated',
                      style: TextStyle(fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                    SizedBox(height: 5),
                    Text('Your latest NIMZO activity',
                      style: TextStyle(fontSize: 13,
                        color: Color(0xfff5e4ff))),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final option in notificationCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: ChoiceChip(
                      key: ValueKey('notifications-tab-$option'),
                      label: Text(option),
                      selected: category == option,
                      showCheckmark: false,
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xffead9fc),
                      labelStyle: TextStyle(
                        color: category == option
                          ? NimzoStyle.primary
                          : const Color(0xff8a8099),
                        fontWeight: FontWeight.w800),
                      side: BorderSide(
                        color: category == option
                          ? NimzoStyle.primary
                          : const Color(0xffe8e2ef)),
                      onSelected: (_) =>
                        setState(() => category = option),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            notifications.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(37),
                child: Center(child: CircularProgressIndicator())),
              error: (_, __) => Column(children: [
                const Text('Notifications could not be loaded'),
                TextButton(
                  onPressed: () =>
                    ref.invalidate(notificationsProvider(category)),
                  child: const Text('Retry')),
              ]),
              data: (rows) {
                if (rows.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(43),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24)),
                    child: Column(children: [
                      const Icon(Icons.notifications_none,
                        size: 54, color: Color(0xffb5a6d5)),
                      const SizedBox(height: 14),
                      Text('No ${category == 'All' ? '' : '$category '}notifications',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xff80758e))),
                    ]),
                  );
                }
                return Column(children: [
                  for (final notification in rows)
                    _NotificationTile(notification: notification),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotificationTile({required this.notification});

  static IconData kindIcon(String category) {
    switch (category.toLowerCase()) {
      case 'messages': return Icons.chat_bubble_rounded;
      case 'gifts': return Icons.card_giftcard_rounded;
      case 'followers': return Icons.people_alt_rounded;
      case 'friends': return Icons.favorite_rounded;
      case 'rooms': return Icons.mic_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  static Color categoryColor(String kind) {
    switch (kind.toLowerCase()) {
      case 'messages': return const Color(0xff4f88ee);
      case 'gifts': return const Color(0xffdf3f9f);
      case 'followers': return const Color(0xff20a5a0);
      case 'friends': return const Color(0xfff06183);
      case 'rooms': return const Color(0xffa547e5);
      default: return const Color(0xffeb9c28);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = notification['category']?.toString() ?? 'system';
    final tint = categoryColor(type);
    final unread = notification['read_at'] == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: unread ? const Color(0xfffefcff) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: unread
          ? const Color(0xffe7d4fa)
          : const Color(0xffedeaf3))),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(19)),
          child: Icon(kindIcon(type), size: 32, color: tint),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['title']?.toString()
                ?? notification['category']?.toString()
                ?? 'Notification',
              maxLines: 2,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w900
                  : FontWeight.w700,
                fontSize: 15,
                color: const Color(0xff3b2d4e))),
            const SizedBox(height: 5),
            Text(notification['body']?.toString() ?? '',
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12, height: 1.35,
                color: Color(0xff8e829f))),
            const SizedBox(height: 7),
            Text(notificationTime(notification['created_at']),
              style: const TextStyle(
                color: Color(0xffa399b1), fontSize: 11)),
          ],
        )),
        if (unread) Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: NimzoStyle.primary)),
      ]),
    );
  }
}

String notificationTime(dynamic value) {
  final at = DateTime.tryParse(value?.toString() ?? '');
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  return '${diff.inMinutes.clamp(0, 59)}m';
}
