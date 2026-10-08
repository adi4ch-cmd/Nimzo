import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile_repository.dart';
import '../wallet/wallet_screen.dart';
import 'gift_repository.dart';
import 'gift_artwork.dart';
import '../../core/widgets/master_ui.dart';
import '../moments/moment_repository.dart';
import '../rooms/presentation/room_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

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
  String? recipient;
  String get receiverId => recipient ?? widget.receiverId;
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
              receiverId: receiverId,
              giftId: g.id,
              qty: requestQuantity,
              key: key!,
            );
        container.invalidate(momentsFeedProvider);
      } else if (widget.roomId == null) {
        await r.sendProfile(
          receiverId: receiverId,
          giftId: g.id,
          qty: requestQuantity,
          key: key!,
        );
      } else {
        await r.send(
          roomId: widget.roomId!,
          receiverId: receiverId,
          giftId: g.id,
          qty: requestQuantity,
          key: key!,
        );
      }
      container.invalidate(walletProvider);
      container.invalidate(profileProvider(receiverId));
      container.invalidate(profileStatsProvider(receiverId));
      if (widget.roomId != null)
        container.invalidate(roomProvider(widget.roomId!));
      container.invalidate(profileGiftsProvider(receiverId));
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
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final recipients = widget.roomId == null
        ? null
        : ref.watch(roomSeatProfilesProvider(widget.roomId!)).valueOrNull;
    final me = ref.watch(currentUserIdProvider);
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Virtual Gifts · ${wallet.valueOrNull == null ? 'Balance unavailable' : '${wallet.valueOrNull!.coins} coins'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)))),
              if (recipients != null && recipients.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        height: 48 * MediaQuery.textScalerOf(context).scale(1),
                        child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final p
                                  in recipients.values.where((p) => p.id != me))
                                ChoiceChip(
                                    label: Text(p.displayName ??
                                        p.username ??
                                        'Nimzo user'),
                                    selected: receiverId == p.id,
                                    onSelected: busy ||
                                            confirming ||
                                            key != null
                                        ? null
                                        : (_) =>
                                            setState(() => recipient = p.id)),
                            ]))),
              Expanded(
                  child: AsyncContent(
                      value: ref.watch(giftCatalogProvider),
                      onRetry: () => ref.invalidate(giftCatalogProvider),
                      builder: (gifts) => gifts.isEmpty
                          ? const EmptyContent('No gifts available')
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                  GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: .82 /
                                          MediaQuery.textScalerOf(context)
                                              .scale(1),
                                      children: [
                                        for (final gift in gifts.where((g) =>
                                            g.name.toLowerCase() !=
                                            'world crown'))
                                          _giftCard(gift)
                                      ]),
                                  for (final gift in gifts.where((g) =>
                                      g.name.toLowerCase() == 'world crown'))
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child:
                                            _giftCard(gift, legendary: true)),
                                  if (gifts.any((g) =>
                                      g.name.toLowerCase() == 'world crown'))
                                    const Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Text(
                                            'World Crown: country theme, room-wide show, special announcement, medal after 15 sends.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: NimzoStyle.muted,
                                                fontSize: 12))),
                                ]))),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Text('Quantity'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                        value: quantity,
                        items: [
                          for (final q in [1, 10, 99])
                            DropdownMenuItem(value: q, child: Text('$q'))
                        ],
                        onChanged: busy || confirming || key != null
                            ? null
                            : (q) => setState(() => quantity = q!)),
                    const Spacer(),
                    GradientButton(
                        onPressed: busy || confirming || selected == null
                            ? null
                            : send,
                        child: Text(busy
                            ? 'Sending…'
                            : key == null
                                ? 'Send'
                                : 'Retry')),
                  ])),
            ])));
  }

  Widget _giftCard(Gift gift, {bool legendary = false}) => InkWell(
      onTap: busy || confirming
          ? null
          : () {
              if (key != null && selected != gift) return;
              setState(() => selected = gift);
            },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
              color: const Color(0xff14082e),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: legendary || selected == gift
                      ? const Color(0xfffbbf24)
                      : Colors.transparent,
                  width: 2)),
          child: legendary
              ? Row(children: [
                  Expanded(
                      child: SizedBox(
                          height: 76,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GiftArtwork(
                                  name: gift.name,
                                  assetPath: gift.assetPath)))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${gift.name} · National Legendary',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(compactNumber(gift.price),
                        style: const TextStyle(
                            color: Color(0xfffde68a), fontSize: 12))
                  ]))
                ])
              : Column(children: [
                  Expanded(
                      child: SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GiftArtwork(
                                  name: gift.name,
                                  assetPath: gift.assetPath)))),
                  const SizedBox(height: 2),
                  Text(gift.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  Text(compactNumber(gift.price),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xfffde68a)))
                ])));
}
