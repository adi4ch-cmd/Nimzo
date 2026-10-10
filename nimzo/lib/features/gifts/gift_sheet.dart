import '../vip/phoenix_widgets.dart';
import '../vip/phoenix_entitlement.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile_repository.dart';
import '../wallet/wallet_screen.dart';
import 'gift_repository.dart';
import 'gift_error.dart';
import 'gift_artwork.dart';
import 'gift_svga_overlay.dart';
import 'gift_celebration_overlay.dart';
import 'yo2_gift_ui.dart';
import 'nimzo_gift_control_art.dart';
import '../../core/widgets/master_ui.dart';
import '../moments/moment_repository.dart';
import '../moments/moments_screen.dart' show momentDetailProvider;
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
  String activeGiftCategory = 'All';
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
        container.invalidate(momentDetailProvider(widget.momentId!));
        container.invalidate(profileMomentsProvider(receiverId));
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
      // Use locally bundled gift artwork after server-confirmed settlement.
      // Room animations are driven separately by verified backend events.
      if (mounted && g.category.toLowerCase() != 'dragon') {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const NimzoGiftControlArt(
                  'video_send_gift.webp',
                  width: 42,
                  height: 42,
                  fallback: Icon(Icons.check_circle_outline, size: 28),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${g.name} × $requestQuantity sent')),
              ],
            ),
          ),
        );
      }
      // Profile and Moment gifts have no room broadcast. The visual effect
      // starts only after the server confirms debit and gifting. Room gifts
      // are animated for all listeners by VerifiedGiftBroadcast instead.
      if (mounted && widget.roomId == null) {
        showSettledPersonalGiftCelebration(
          context,
          giftName: g.name,
          quantity: requestQuantity,
          unitPrice: g.price,
          assetPath: g.assetPath,
          recipientName: ref.read(profileProvider(receiverId)).valueOrNull
                  ?.displayName ??
              ref.read(profileProvider(receiverId)).valueOrNull?.username,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      // Known RPC rejections roll back settlement, so a new selection is safe.
      // Uncertain responses keep the original key and payload for retry.
      if (mounted && error is GiftRejectedException) {
        setState(() => key = null);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is GiftRejectedException
                  ? error.message
                  : 'Gift was not confirmed. Retry to check this same request.',
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
    final phoenix = me != null &&
        ref.watch(phoenixEntitlementProvider(me)).asData?.value?.isPhoenix ==
            true;
    return PhoenixDecoration(
      userId: me,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              if (phoenix)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhoenixMark(),
                      SizedBox(width: 8),
                      Text(
                        'NIMZO Royal VIP gift tray',
                        style: TextStyle(
                          color: phoenixGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const NimzoGiftControlArt(
                        'video_send_gift.webp',
                        width: 36,
                        height: 36,
                        fallback: Icon(Icons.card_giftcard, size: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NIMZO Gifts · ${wallet.valueOrNull == null ? 'Balance unavailable' : '${compactNumber(wallet.valueOrNull!.coins)} coins'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Room members can gift themselves even when not seated on
              // a microphone. The seat roster must not hide "Myself".
              if (widget.roomId != null &&
                  me != null &&
                  recipients?.values.any((p) => p.id == me) != true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ChoiceChip(
                      label: const Text('Myself'),
                      selected: receiverId == me,
                      onSelected: busy || confirming || key != null
                          ? null
                          : (_) => setState(() => recipient = me),
                    ),
                  ),
                ),
              if (recipients != null && recipients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 48 * MediaQuery.textScalerOf(context).scale(1),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in recipients.values)
                          ChoiceChip(
                            label: Text(
                              p.id == me
                                  ? 'Myself'
                                  : p.displayName ?? p.username ?? 'Nimzo user',
                            ),
                            selected: receiverId == p.id,
                            onSelected: busy || confirming || key != null
                                ? null
                                : (_) => setState(() => recipient = p.id),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: AsyncContent(
                  value: ref.watch(giftCatalogProvider),
                  onRetry: () => ref.invalidate(giftCatalogProvider),
                  builder: (gifts) => gifts.isEmpty
                      ? const EmptyContent('No gifts available')
                      : CustomScrollView(
                          slivers: [
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Text(
                                  'GIFT COLLECTION',
                                  style: TextStyle(
                                    letterSpacing: 2,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xffd6ad61),
                                  ),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 46,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final category in nimzoGiftCategories(
                                      gifts.map((gift) => gift.category),
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(category),
                                          selected:
                                              activeGiftCategory == category,
                                          onSelected: busy ||
                                                  confirming ||
                                                  key != null
                                              ? null
                                              : (_) => setState(() {
                                                    activeGiftCategory =
                                                        category;
                                                    if (selected != null &&
                                                        !giftMatchesCategory(
                                                          selected!.category,
                                                          category,
                                                        )) {
                                                      selected = null;
                                                    }
                                                  }),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.sizeOf(context).width < 390 ? 2 : 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: .76 /
                                      MediaQuery.textScalerOf(context).scale(1),
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final gift = gifts
                                        .where(
                                          (g) => giftMatchesCategory(
                                            g.category,
                                            activeGiftCategory,
                                          ),
                                        )
                                        .elementAt(index);
                                    return _giftCard(
                                      gift,
                                      legendary: gift.price == 35000000 ||
                                          gift.price == 50000000,
                                    );
                                  },
                                  childCount: gifts
                                      .where(
                                        (g) => giftMatchesCategory(
                                          g.category,
                                          activeGiftCategory,
                                        ),
                                      )
                                      .length,
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Gift prices and delivery are verified by the NIMZO server.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: NimzoStyle.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          color: Color(0xff0f8d59), size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Total · ${compactNumber(selected!.price * quantity)} coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff0c7650),
                          ),
                        ),
                      ),
                      if (key != null)
                        const Text(
                          'Retry same request',
                          style: TextStyle(fontSize: 11, color: Color(0xff6b7280)),
                        ),
                    ],
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
                        for (final q in [1, 10, 50, 99, 100, 999])
                          DropdownMenuItem(value: q, child: Text('$q')),
                      ],
                      onChanged: busy || confirming || key != null
                          ? null
                          : (q) => setState(() => quantity = q!),
                    ),
                    const Spacer(),
                    GradientButton(
                      onPressed:
                          busy || confirming || selected == null ? null : send,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NimzoGiftControlArt(
                            'icon_gift_modal.webp',
                            width: 18,
                            height: 18,
                            fallback: Icon(Icons.send, size: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            busy
                                ? 'Sending…'
                                : key == null
                                    ? 'Send'
                                    : 'Retry',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Premium, accurately labelled artwork for the 20 real server catalog
  /// gifts. Only Rocket and Sports Car have verified original SVGA playback.
  /// All other icons are illustrations, never pretend video stills.
  Widget _giftCard(Gift gift, {bool legendary = false}) {
    final highlighted = selected?.id == gift.id;
    final realAnimation = freeGiftAnimationForName(gift.name) != null;
    final accent = gift.category.toLowerCase() == 'dragon'
        ? const Color(0xffffd08a)
        : gift.price >= 1000000
            ? const Color(0xffd6b8ff)
            : const Color(0xffa8e3cb);
    return Semantics(
      label: '${gift.name}, ${gift.price} coins${realAnimation ? ', original animated gift' : ''}',
      button: true,
      child: InkWell(
        key: ValueKey('gift-card-${gift.id}'),
        borderRadius: BorderRadius.circular(15),
        onTap: busy || confirming
            ? null
            : () {
                if (key != null && selected?.id != gift.id) return;
                setState(() => selected = gift);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? const [Color(0xff264b3e), Color(0xff0f2929)]
                  : const [Color(0xff1b2831), Color(0xff111923)],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: highlighted ? const Color(0xff6fdda9)
                  : legendary ? const Color(0xffd8b26c)
                  : const Color(0xff374550),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xff24343a),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: GiftArtwork(
                          name: gift.name,
                          assetPath: gift.assetPath,
                        ),
                      ),
                    ),
                    if (realAnimation)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff0d573f),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                            child: Text('SVGA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    if (highlighted)
                      const Positioned(
                        bottom: 3,
                        right: 3,
                        child: Icon(Icons.check_circle,
                            color: Color(0xff7df1bd), size: 19),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                gift.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NimzoGiftControlArt(
                    'icon_gift_modal.webp', width: 13, height: 13),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      compactNumber(gift.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11,
                        color: accent, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
