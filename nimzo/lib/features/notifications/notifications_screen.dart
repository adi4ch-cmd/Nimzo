import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'notification_repository.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: notificationCategories.length,
        child: Scaffold(
          appBar: AppBar(title: const Text('Notifications'), bottom: TabBar(isScrollable: true, tabs: [for (final c in notificationCategories) Tab(text: c)])),
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
        data: (l) => l.isEmpty ? const EmptyView(title: 'Nothing here yet') : ListView(children: [for (final n in l) ListTile(title: Text(n['title'] ?? ''), subtitle: Text(n['body'] ?? ''))]),
      );
}
