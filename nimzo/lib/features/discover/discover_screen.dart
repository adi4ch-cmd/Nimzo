import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/reference_widgets.dart';
import '../profile/profile.dart';
import '../profile/profile_repository.dart';
import '../social/follow_button.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _State();
}

class _State extends ConsumerState<DiscoverScreen> {
  final query = TextEditingController();
  AsyncValue<List<Profile>> results = const AsyncData([]);
  int generation = 0;
  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final run = ++generation;
    setState(() => results = const AsyncLoading());
    final data = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).search(query.text),
    );
    if (mounted && run == generation) setState(() => results = data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Search')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: query,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                labelText: 'Nimzo ID or name',
                suffixIcon: IconButton(
                  onPressed: search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            AsyncContent(
              value: results,
              onRetry: search,
              builder: (p) => p.isEmpty
                  ? const EmptyContent('No results')
                  : Column(
                      children: [
                        for (final user in p)
                          ListTile(
                            leading: NimzoAvatar(name: user.displayName ?? 'N'),
                            title: Text(
                              user.displayName ?? user.username ?? 'Nimzo user',
                            ),
                            subtitle: Text('ID:${user.nimzoId}'),
                            trailing: ReferenceFollowButton(userId: user.id),
                            onTap: () => context.push('/profile/${user.id}'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
}
