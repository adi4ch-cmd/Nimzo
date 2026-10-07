import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/reference_widgets.dart';
import 'notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: ListView(
          children: [
            AsyncContent(
              value: ref.watch(notificationsProvider('All')),
              onRetry: () => ref.invalidate(notificationsProvider('All')),
              builder: (rows) => rows.isEmpty
                  ? const EmptyContent('No notifications yet')
                  : Column(
                      children: [
                        for (final r in rows)
                          ListTile(
                            title: Text(
                              r['title']?.toString() ??
                                  r['category']?.toString() ??
                                  'Notification',
                            ),
                            subtitle: Text(r['body']?.toString() ?? ''),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
}
