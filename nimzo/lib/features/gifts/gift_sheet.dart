import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile_repository.dart';
import '../wallet/wallet_screen.dart';
import 'gift_repository.dart';
import 'gift_artwork.dart';
import '../moments/moment_repository.dart';
import '../rooms/presentation/room_controller.dart';

Future<void> showProfileGiftSheet(BuildContext context, String receiverId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GiftSheet(receiverId: receiverId),
    );
Future<void> showRoomGiftSheet(
  BuildContext context,
  String roomId,
  String receiverId,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GiftSheet(receiverId: receiverId, roomId: roomId),
    );

Future<void> showMomentGiftSheet(
  BuildContext context,
  String momentId,
  String receiverId,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GiftSheet(receiverId: receiverId, momentId: momentId),
    );

class GiftSheet extends ConsumerStatefulWidget {
  final String receiverId;
  final String? roomId;
  final String? momentId;
  const GiftSheet({
    super.key,
    required this.receiverId,
    this.roomId,
    this.momentId,
  });
  @override
  ConsumerState<GiftSheet> createState() => _State();
}

class _State extends ConsumerState<GiftSheet> {
  Gift? selected;
  bool busy = false;
  bool confirming = false;
  int quantity = 1;
  String? key;
  Future<void> send() async {
    if (selected == null || busy || confirming) return;
    final gift = selected!;
    final requestQuantity = quantity;
    setState(() => confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Send gift?'),
        content: Text(
          '${gift.name} × $requestQuantity · ${gift.price * requestQuantity} coins',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => confirming = false);
    if (confirmed != true) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final me = ref.read(currentUserIdProvider);
    key ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    setState(() => busy = true);
    try {
      final r = ref.read(giftRepositoryProvider), g = gift;
      if (widget.momentId != null) {
        await ref.read(momentRepositoryProvider).sendGift(
              momentId: widget.momentId!,
              receiverId: widget.receiverId,
              giftId: g.id,
              qty: requestQuantity,
              key: key!,
            );
        container.invalidate(momentsFeedProvider);
      } else if (widget.roomId == null) {
        await r.sendProfile(
          receiverId: widget.receiverId,
          giftId: g.id,
          qty: requestQuantity,
          key: key!,
        );
      } else {
        await r.send(
          roomId: widget.roomId!,
          receiverId: widget.receiverId,
          giftId: g.id,
          qty: requestQuantity,
          key: key!,
        );
      }
      container.invalidate(walletProvider);
      container.invalidate(profileProvider(widget.receiverId));
      container.invalidate(profileStatsProvider(widget.receiverId));
      if (widget.roomId != null)
        container.invalidate(roomProvider(widget.roomId!));
      container.invalidate(profileGiftsProvider(widget.receiverId));
      if (me != null) {
        container.invalidate(profileProvider(me));
        container.invalidate(profileStatsProvider(me));
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gift was not confirmed. Retry to check this same request.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Virtual Gifts',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              Text(
                ref.watch(walletProvider).valueOrNull == null
                    ? 'Balance unavailable'
                    : '${ref.watch(walletProvider).valueOrNull!.coins} coins',
              ),
              Expanded(
                child: AsyncContent(
                  value: ref.watch(giftCatalogProvider),
                  onRetry: () => ref.invalidate(giftCatalogProvider),
                  builder: (gifts) => gifts.isEmpty
                      ? const EmptyContent('No gifts available')
                      : GridView.count(
                          crossAxisCount: 3,
                          padding: const EdgeInsets.all(16),
                          childAspectRatio: .85,
                          children: [
                            for (final gift in gifts)
                              InkWell(
                                onTap: busy || confirming
                                    ? null
                                    : () {
                                        if (key != null && selected != gift)
                                          return;
                                        setState(() => selected = gift);
                                      },
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selected == gift
                                        ? const Color(0xfff1e6ff)
                                        : const Color(0xfffaf5ff),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: GiftArtwork(
                                          name: gift.name,
                                          assetPath: gift.assetPath,
                                        ),
                                      ),
                                      Text(
                                        gift.name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        '${gift.price}',
                                        style: const TextStyle(fontSize: 12),
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Quantity'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: quantity,
                      items: [
                        for (final q in [1, 10, 99])
                          DropdownMenuItem(value: q, child: Text('$q')),
                      ],
                      onChanged: busy || confirming || key != null
                          ? null
                          : (q) => setState(() => quantity = q!),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed:
                          busy || confirming || selected == null ? null : send,
                      child: Text(
                        busy
                            ? 'Sending…'
                            : key == null
                                ? 'Send'
                                : 'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
