import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gift_purchase_keys.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../profile/profile_repository.dart';
import '../wallet/wallet_screen.dart';
import 'gift_repository.dart';
import 'private_animal_gifts.dart';
import 'gift_error.dart';
import 'gift_artwork.dart';
import 'gift_svga_overlay.dart';
import 'remote_gift_svga_overlay.dart';
import 'gift_video_overlay.dart';
import 'hall_of_fame_vap_overlay.dart';
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
  bool previewing = false;
  bool _previewLoading = false;
  int quantity = 1;
  String activeGiftCategory = 'All';
  String? key;
  PendingGiftPurchase? _pendingPurchase;
  GiftPurchaseKeys? _purchaseKeys;
  bool _restoring = true;
  String? _restoreError;
  int _accountGeneration = 0;
  String get _purchaseContext => widget.momentId != null
      ? 'moment:${widget.momentId}'
      : widget.roomId != null
          ? 'room:${widget.roomId}'
          : 'profile:${widget.receiverId}';

  @override
  void initState() {
    super.initState();
    _restorePending(ref.read(currentUserIdProvider));
  }

  Future<void> _restorePending(String? account) async {
    final generation = ++_accountGeneration;
    if (mounted)
      setState(() {
        _restoring = true;
        _restoreError = null;
        selected = null;
        recipient = null;
        quantity = 1;
        key = null;
        _pendingPurchase = null;
      });
    try {
      final store = GiftPurchaseKeys(await SharedPreferences.getInstance());
      final pending =
          account == null ? null : store.read(account, _purchaseContext);
      if (!mounted || generation != _accountGeneration) return;
      setState(() {
        _purchaseKeys = store;
        _pendingPurchase = pending;
        key = pending?.key;
        if (pending != null) {
          selected = Gift(pending.giftId, pending.giftName, pending.category,
              pending.expectedTotal ~/ pending.quantity, pending.assetPath,
              requiresApprovedMedia: true);
          recipient = pending.receiverId;
          quantity = pending.quantity;
        }
        _restoring = false;
      });
    } catch (_) {
      if (mounted && generation == _accountGeneration)
        setState(() {
          _restoring = false;
          _restoreError =
              'Saved gift receipt unavailable. Reopen Gifts before sending.';
        });
    }
  }

  /// No-charge decoder test for the verified owner of test ID 100005.
  /// The backend independently authorizes each signed QA media URL.
  /// Never call send_gift, create gift events, or change wallet balances here.
  Future<void> _testGiftAnimation() async {
    final gift = selected;
    if (!kDebugMode ||
        gift == null ||
        busy ||
        confirming ||
        previewing ||
        _restoring ||
        _restoreError != null) return;
    final bundled = freeGiftAnimationForId(gift.id);
    String? mediaUrl;
    if (bundled == null) {
      if (!privateAnimalVapGiftIds.contains(gift.id)) return;
      try {
        mediaUrl = await ref
            .read(giftRepositoryProvider)
            .qaGiftAnimationUrl(gift.id)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gift test video unavailable; 0 coins charged.'),
            ),
          );
        }
        return;
      }
      if (mediaUrl == null) return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bundled != null)
              FreeGiftSvgaOverlay(
                source: bundled,
                giftName: gift.name,
                sender: 'Test',
                recipient: 'Test',
                quantity: 1,
                onFinished: () {
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              )
            else
              HallOfFameVapOverlay(
                source: mediaUrl!,
                giftName: gift.name,
                sender: 'Test',
                recipient: 'Test',
                quantity: 1,
                onFinished: () {
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
            const Positioned(
              top: 38,
              left: 12,
              child: SafeArea(
                child: Text(
                  'FREE PLAYBACK TEST · 0 COINS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 38,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Preview reads approved media only; it never submits a gift transaction.
  Future<void> _previewGift() async {
    final gift = selected;
    if (gift == null ||
        busy ||
        confirming ||
        previewing ||
        _restoring ||
        _restoreError != null) return;
    setState(() {
      previewing = true;
      _previewLoading = true;
    });
    try {
      final bundled = freeGiftAnimationForId(gift.id);
      final media = bundled == null
          ? await ref
              .read(giftRepositoryProvider)
              .approvedAnimationMedia(gift.id)
              .timeout(const Duration(seconds: 12))
          : null;
      if (!mounted) return;
      setState(() => _previewLoading = false);
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        barrierColor: const Color(0xf208201b),
        builder: (dialogContext) {
          void close() {
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          }

          return Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bundled != null)
                  FreeGiftSvgaOverlay(
                    source: bundled,
                    giftName: gift.name,
                    sender: 'Preview',
                    recipient: 'Preview',
                    quantity: 1,
                    onFinished: close,
                  )
                else if (media?.kind == 'svga')
                  RemoteGiftSvgaOverlay(
                    soundEnabled: media!.soundEnabled,
                    source: media.url,
                    publication: media.publication,
                    giftName: gift.name,
                    sender: 'Preview',
                    recipient: 'Preview',
                    quantity: 1,
                    onFinished: close,
                  )
                else if (media?.kind == 'vap')
                  HallOfFameVapOverlay(
                    muted: media!.publication != null && !media.soundEnabled,
                    source: media.url,
                    publication: media.publication,
                    giftName: gift.name,
                    sender: 'Preview',
                    recipient: 'Preview',
                    quantity: 1,
                    onFinished: close,
                  )
                else if (media?.kind == 'mp4')
                  GiftVideoOverlay(
                    muted: !media!.soundEnabled,
                    source: media.url,
                    publication: media.publication,
                    giftName: gift.name,
                    sender: 'Preview',
                    recipient: 'Preview',
                    onFinished: close,
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 220,
                            child: GiftArtwork(
                              name: gift.name,
                              assetPath: gift.assetPath,
                              publication: gift.thumbnailPublication,
                              requiresPublication: gift.requiresApprovedMedia ||
                                  gift.requiresThumbnailPublication,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Artwork preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Animation preview is currently unavailable.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xffc8d8d2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 20,
                  right: 12,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${gift.name} · Free preview',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: close,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview unavailable. No coins were charged.'),
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          previewing = false;
          _previewLoading = false;
        });
    }
  }

  Future<void> send() async {
    if (selected == null ||
        busy ||
        confirming ||
        previewing ||
        _restoring ||
        _restoreError != null) return;
    final me = ref.read(currentUserIdProvider);
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please sign in before sending a gift.')));
      return;
    }
    final gift = selected!;
    final requestQuantity = _pendingPurchase?.quantity ?? quantity;
    final expectedTotal =
        _pendingPurchase?.expectedTotal ?? gift.price * requestQuantity;
    final requestReceiver = _pendingPurchase?.receiverId ?? receiverId;
    setState(() => confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            _pendingPurchase == null ? 'Send gift?' : 'Check pending gift?'),
        content: Text(
          '${gift.name} × $requestQuantity · $expectedTotal coins',
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
    if (ref.read(currentUserIdProvider) != me) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final request = _pendingPurchase ??
        PendingGiftPurchase(
          accountId: me,
          context: _purchaseContext,
          receiverId: requestReceiver,
          giftId: gift.id,
          giftName: gift.name,
          category: gift.category,
          quantity: requestQuantity,
          expectedTotal: expectedTotal,
          key: PendingGiftPurchase.newKey(),
          assetPath: gift.assetPath,
        );
    final store = _purchaseKeys;
    if (store == null) return;
    setState(() => busy = true);
    try {
      await store.prepare(request);
      if (!mounted || ref.read(currentUserIdProvider) != me) return;
      setState(() {
        _pendingPurchase = request;
        key = request.key;
      });
      final r = ref.read(giftRepositoryProvider), g = gift;
      if (widget.momentId != null) {
        await ref.read(momentRepositoryProvider).sendGift(
              momentId: widget.momentId!,
              receiverId: requestReceiver,
              giftId: g.id,
              qty: requestQuantity,
              key: request.key,
              expectedTotal: expectedTotal,
            );
        if (!mounted || ref.read(currentUserIdProvider) != me) {
          await store.complete(request);
          return;
        }
        container.invalidate(momentsFeedProvider);
        container.invalidate(momentDetailProvider(widget.momentId!));
        container.invalidate(profileMomentsProvider(receiverId));
      } else if (widget.roomId == null) {
        await r.sendProfile(
          receiverId: requestReceiver,
          giftId: g.id,
          qty: requestQuantity,
          key: request.key,
          expectedTotal: expectedTotal,
        );
      } else {
        await r.send(
          roomId: widget.roomId!,
          receiverId: requestReceiver,
          giftId: g.id,
          qty: requestQuantity,
          key: request.key,
          expectedTotal: expectedTotal,
        );
      }
      await store.complete(request);
      if (!mounted || ref.read(currentUserIdProvider) != me) return;
      setState(() {
        _pendingPurchase = null;
        key = null;
      });
      container.invalidate(walletProvider);
      container.invalidate(profileProvider(receiverId));
      container.invalidate(profileStatsProvider(receiverId));
      if (widget.roomId != null)
        container.invalidate(roomProvider(widget.roomId!));
      container.invalidate(profileProvider(me));
      container.invalidate(profileStatsProvider(me));
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
        GiftPlaybackMedia? personalMedia;
        if (g.requiresApprovedMedia || privateAnimalVapGiftIds.contains(g.id)) {
          try {
            personalMedia = await r
                .approvedAnimationMedia(g.id)
                .timeout(const Duration(seconds: 12));
          } catch (_) {}
        }
        if (!mounted || ref.read(currentUserIdProvider) != me) return;
        showSettledPersonalGiftCelebration(
          context,
          giftName: g.name,
          quantity: requestQuantity,
          unitPrice: g.price,
          assetPath: g.assetPath,
          thumbnailPublication: g.thumbnailPublication,
          requiresThumbnailPublication:
              g.requiresApprovedMedia || g.requiresThumbnailPublication,
          media: personalMedia,
          requiresAnimation: g.requiresApprovedMedia,
          recipientName:
              ref.read(profileProvider(receiverId)).valueOrNull?.displayName ??
                  ref.read(profileProvider(receiverId)).valueOrNull?.username,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      // Known RPC rejections roll back settlement, so a new selection is safe.
      // Uncertain responses keep the original key and payload for retry.
      if (error is GiftRejectedException) {
        try {
          await store.complete(request);
          if (mounted && ref.read(currentUserIdProvider) == me)
            setState(() {
              key = null;
              _pendingPurchase = null;
            });
        } catch (_) {
          // Keep the immutable request when receipt persistence is uncertain.
        }
      }
      if (mounted && ref.read(currentUserIdProvider) == me)
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
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) _restorePending(next);
    });
    final wallet = ref.watch(walletProvider);
    final me = ref.watch(currentUserIdProvider);
    final recipients = widget.roomId == null
        ? null
        : ref.watch(roomSeatProfilesProvider(widget.roomId!)).valueOrNull;
    return Material(
      color: const Color(0xfff4f8f5),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffc9d9d0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selected?.offline == true
                                  ? 'Gifts · Offline'
                                  : 'NIMZO Gifts',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: Color(0xff123d30),
                              ),
                            ),
                            Text(
                              wallet.valueOrNull == null
                                  ? 'Wallet balance unavailable'
                                  : '${compactNumber(wallet.valueOrNull!.coins)} coins  ·  ${compactNumber(wallet.valueOrNull!.diamonds)} diamonds',
                              key: const ValueKey(
                                'gift-tray-coin-diamond-balances',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff63766c),
                              ),
                            ),
                          ],
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
                      onSelected: busy ||
                              confirming ||
                              previewing ||
                              _restoring ||
                              _restoreError != null ||
                              key != null
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
                            onSelected: busy ||
                                    confirming ||
                                    previewing ||
                                    _restoring ||
                                    _restoreError != null ||
                                    key != null
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
                                  'A little gift. A big moment.',
                                  style: TextStyle(
                                    letterSpacing: .1,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff987330),
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
                                                  previewing ||
                                                  key != null
                                              ? null
                                              : (_) => setState(() {
                                                    activeGiftCategory =
                                                        category;
                                                    if (selected != null &&
                                                        !giftMatchesCategory(
                                                          selected!.category,
                                                          category,
                                                          giftName:
                                                              selected!.name,
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
                                  crossAxisCount:
                                      MediaQuery.sizeOf(context).width < 390
                                          ? 2
                                          : 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: .76 /
                                      MediaQuery.textScalerOf(context).scale(1),
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final active = gifts
                                        .where(
                                          (g) => giftMatchesCategory(
                                            g.category,
                                            activeGiftCategory,
                                            giftName: g.name,
                                          ),
                                        )
                                        .toList();
                                    final gift = active[index];
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
                                          giftName: g.name,
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
                                  'Choose a gift, preview it, and make their day.',
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
              if (_restoring ||
                  _restoreError != null ||
                  _pendingPurchase != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                      _restoring
                          ? 'Checking saved gift receipt…'
                          : _restoreError ??
                              'Pending gift · ${_pendingPurchase!.expectedTotal} coins originally confirmed. Retry checks the same request.',
                      key: const ValueKey('gift-pending-receipt'),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff987330))),
                ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: Color(0xff0f8d59),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Total · ${compactNumber(_pendingPurchase?.expectedTotal ?? selected!.price * quantity)} coins',
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
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff6b7280),
                          ),
                        ),
                    ],
                  ),
                ),
              if (kDebugMode &&
                  me == '15e10a70-e8fe-4a1f-afd0-1292ffde3978' &&
                  selected != null &&
                  (privateAnimalVapGiftIds.contains(selected!.id) ||
                      freeGiftAnimationForId(selected!.id) != null))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('gift-playback-free-qa'),
                    onPressed: busy ||
                            confirming ||
                            previewing ||
                            _restoring ||
                            _restoreError != null
                        ? null
                        : _testGiftAnimation,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Test Animation (FREE)'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (selected != null)
                      IconButton(
                        key: const ValueKey('gift-preview-selected'),
                        tooltip: 'Free gift preview',
                        onPressed: busy ||
                                confirming ||
                                previewing ||
                                _restoring ||
                                _restoreError != null
                            ? null
                            : _previewGift,
                        icon: _previewLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.play_circle_outline_rounded,
                                color: Color(0xff08754d),
                              ),
                      ),
                    const Text('Qty'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: quantity,
                      items: [
                        for (final q in [1, 10, 50, 99, 100, 999])
                          DropdownMenuItem(value: q, child: Text('$q')),
                      ],
                      onChanged: busy ||
                              confirming ||
                              previewing ||
                              _restoring ||
                              _restoreError != null ||
                              key != null
                          ? null
                          : (q) => setState(() => quantity = q!),
                    ),
                    const Spacer(),
                    GradientButton(
                      onPressed: busy ||
                              confirming ||
                              previewing ||
                              _restoring ||
                              _restoreError != null ||
                              selected == null ||
                              (selected!.offline && _pendingPurchase == null)
                          ? null
                          : send,
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

  Widget _giftCard(Gift gift, {bool legendary = false}) {
    final highlighted = selected?.id == gift.id;
    final realAnimation = freeGiftAnimationForName(gift.name) != null ||
        privateAnimalVapGiftIds.contains(gift.id) ||
        (gift.requiresApprovedMedia &&
            const {'svga', 'vap', 'mp4'}.contains(gift.playbackKind));
    const accent = Color(0xff987330);
    return Semantics(
      label:
          '${gift.name}, ${gift.price} coins${realAnimation ? ', original animated gift' : ''}',
      button: true,
      selected: highlighted,
      child: InkWell(
        key: ValueKey('gift-card-${gift.id}'),
        borderRadius: BorderRadius.circular(15),
        onTap: busy ||
                confirming ||
                previewing ||
                _restoring ||
                _restoreError != null ||
                key != null
            ? null
            : () => setState(() => selected = gift),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? const [Color(0xffe0f2e8), Color(0xfff1faf5)]
                  : const [Colors.white, Color(0xfff9fcfa)],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: highlighted
                  ? const Color(0xff08754d)
                  : legendary
                      ? NimzoStyle.orange
                      : const Color(0xff6c5299),
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
                        color: const Color(0xffeef4ef),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: GiftArtwork(
                          name: gift.name,
                          assetPath: gift.assetPath,
                          publication: gift.thumbnailPublication,
                          requiresPublication: gift.requiresApprovedMedia ||
                              gift.requiresThumbnailPublication,
                        ),
                      ),
                    ),
                    if (realAnimation)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff164c39),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: const Text(
                              'Animated',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (highlighted)
                      const Positioned(
                        bottom: 3,
                        right: 3,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xff08754d),
                          size: 19,
                        ),
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
                  color: Color(0xff163c2d),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NimzoGiftControlArt(
                    'icon_gift_modal.webp',
                    width: 13,
                    height: 13,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      compactNumber(gift.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
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
