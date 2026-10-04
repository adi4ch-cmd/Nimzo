import '../../core/widgets/nimzo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import '../profile/profile_repository.dart';
import 'admin_repository.dart';

final adminReportsProvider = FutureProvider((ref) => ref.watch(adminRepositoryProvider).reports());

/// Minimal in-app moderation. Every action is authorised server-side.
/// The full dashboard (users, rooms, coins, banners, announcements) belongs in a separate web app.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _S();
}

class _S extends ConsumerState<AdminScreen> {
  final _q = TextEditingController();
  List<dynamic> found = [];
  @override
  void dispose() { _q.dispose(); super.dispose(); }
  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(title: const Text('Admin'), bottom: const TabBar(tabs: [Tab(text: 'Users'), Tab(text: 'Reports')])),
          body: TabBarView(children: [
            Column(children: [
              Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _q, decoration: const InputDecoration(hintText: 'Name or Nimzo ID', prefixIcon: Icon(Icons.search)),
                onSubmitted: (v) async { final r = await ref.read(profileRepositoryProvider).search(v.trim()); setState(() => found = r); })),
              Expanded(child: ListView(children: [
                for (final u in found) ListTile(
                  title: Text(u.displayName ?? 'User'), subtitle: Text('ID ${u.nimzoId}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (s) async { try { await ref.read(adminRepositoryProvider).setStatus(u.id, s); _snack('Updated'); } catch (e) { _snack('$e'); } },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'suspended', child: Text('Suspend')), PopupMenuItem(value: 'banned', child: Text('Ban')), PopupMenuItem(value: 'active', child: Text('Unban / activate'))],
                  ),
                ),
              ])),
            ]),
            ref.watch(adminReportsProvider).when(
              loading: () => const ShimmerView(),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(adminReportsProvider)),
              data: (l) => l.isEmpty ? const EmptyView(title: 'No open reports') : ListView(children: [for (final r in l) ListTile(title: Text('${r['target_type']}: ${r['reason'] ?? ''}'), subtitle: Text('${r['status']}'))]),
            ),
          ]),
        ),
      );
}
