import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../profile/profile_collections.dart';
import '../profile/profile_presentation.dart';
import '../store/store_badge.dart';
import '../store/store_repository.dart';

/// Server-authorized medals replace the old placeholder room medal previews.
class HonorWallContent extends ConsumerStatefulWidget {
  const HonorWallContent({super.key});

  @override
  ConsumerState<HonorWallContent> createState() => _HonorWallContentState();
}

class _HonorWallContentState extends ConsumerState<HonorWallContent> {
  String? _equipping;

  void _refresh(String id) {
    ref.invalidate(royalBagProvider(id));
    ref.invalidate(royalCatalogProvider);
    ref.invalidate(equippedRoyalMedalProvider(id));
    ref.invalidate(profileCollectionProvider((id, ProfileCollection.medal)));
  }

  Future<void> _equip(String id, RoyalBagItem item) async {
    if (_equipping != null || item.equipped) return;
    setState(() => _equipping = item.id);
    try {
      await ref.read(royalStoreRepositoryProvider).equip(item.id);
      if (!mounted) return;
      _refresh(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medal equipped on your NIMZO profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not equip medal. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _equipping = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    if (id == null) {
      return const Center(child: Text('Sign in to view your medals.'));
    }
    final bag = ref.watch(royalBagProvider(id));
    final catalog = ref.watch(royalCatalogProvider);
    final owned = bag.valueOrNull ?? const <RoyalBagItem>[];
    final selected = owned.where((item) => item.equipped).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xff182d24), Color(0xff34503b)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium, color: Color(0xfff2d797)),
                  SizedBox(width: 10),
                  Text('NIMZO MEDALS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                bag.isLoading
                    ? 'Checking your medals…'
                    : bag.hasError
                        ? 'Medals temporarily unavailable'
                        : '${owned.length} owned · ${selected?.name ?? 'None equipped'}',
                style: const TextStyle(color: Color(0xfff2e8ce)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only medals verified by the NIMZO server can be equipped.',
                style: TextStyle(color: Color(0xffcedbd0), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text('MY MEDALS',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton.icon(
              onPressed: () => _refresh(id),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bag.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _error(
            'Your medals could not be loaded.',
            () => ref.invalidate(royalBagProvider(id)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _empty(context);
            }
            final sorted = [...items]
              ..sort((a, b) {
                if (a.equipped != b.equipped) return a.equipped ? -1 : 1;
                return a.name.compareTo(b.name);
              });
            return _grid([
              for (final item in sorted)
                _tile(
                  name: item.name,
                  image: item.image,
                  detail: item.expiry == null
                      ? 'Owned'
                      : 'Expires ${item.expiry!.toIso8601String().split('T').first}',
                  action: item.equipped ? 'Equipped' : 'Equip',
                  enabled: !item.equipped && _equipping == null,
                  highlighted: item.equipped,
                  onTap: () => _equip(id, item),
                ),
            ]);
          },
        ),
        const SizedBox(height: 24),
        const Text('ROYAL COLLECTION',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text(
          'Browse licensed medal artwork. All purchases are handled by the NIMZO Store.',
          style: TextStyle(color: NimzoStyle.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _error(
            'The Royal Collection is temporarily unavailable.',
            () => ref.invalidate(royalCatalogProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No medals are currently on sale.');
            }
            final ids = owned.map((item) => item.id).toSet();
            return _grid([
              for (final item in items)
                _tile(
                  name: item.name,
                  image: item.image,
                  detail: ids.contains(item.id)
                      ? 'In your Bag'
                      : '${compactNumber(item.price)} coins',
                  action: ids.contains(item.id) ? 'Owned' : 'View in Store',
                  enabled: !ids.contains(item.id),
                  highlighted: ids.contains(item.id),
                  onTap: () => context.push('/store'),
                ),
            ]);
          },
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NimzoStyle.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NimzoStyle.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.military_tech_outlined, size: 38),
            const SizedBox(height: 10),
            const Text('No earned or purchased medals yet.'),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.push('/store'),
              child: const Text('Explore NIMZO Store'),
            ),
          ],
        ),
      );

  Widget _error(String message, VoidCallback retry) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      );

  Widget _grid(List<Widget> cards) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640
              ? 3
              : constraints.maxWidth >= 350
                  ? 2
                  : 1;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
      );

  Widget _tile({
    required String name,
    required String image,
    required String detail,
    required String action,
    required bool enabled,
    required bool highlighted,
    required VoidCallback onTap,
  }) =>
      Container(
        height: 218,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xfffff8e9) : NimzoStyle.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? const Color(0xffc99548)
                : const Color(0xffe6e4de),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: CollectibleArtwork(
                  item: {'name': name, 'image_path': image},
                  size: 88,
                ),
              ),
            ),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: NimzoStyle.muted, fontSize: 11)),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: enabled ? onTap : null,
                child: Text(action,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      );
}
