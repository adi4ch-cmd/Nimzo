import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gift_repository.dart';
import 'hall_of_fame_gift.dart';
import 'zodiac_gifts.dart';
import 'private_animal_gifts.dart';
import 'hall_of_fame_vap_overlay.dart';
import 'gift_video_overlay.dart';
import 'gift_svga_overlay.dart';
import 'gift_receipt.dart';
import 'nimzo_gift_control_art.dart';

/// Server-settled gift announcements. Initial history is never replayed.
class VerifiedGiftBroadcast extends ConsumerStatefulWidget {
  const VerifiedGiftBroadcast({
    super.key,
    required this.roomId,
    required this.countryCode,
  });
  final String roomId, countryCode;
  @override
  ConsumerState<VerifiedGiftBroadcast> createState() => _BroadcastState();
}

class _BroadcastState extends ConsumerState<VerifiedGiftBroadcast>
    with WidgetsBindingObserver {
  final Set<String> _seen = {};
  final List<Map<String, dynamic>> _pending = [];
  Map<String, dynamic>? _active;
  Map<String, String> _participants = const {};
  Timer? _timer;
  String? _video;
  bool _loading = false;
  bool _foreground = true;
  Timer? _mediaTimer;
  Completer<String?>? _mediaWait;
  Timer? _recoveryTimer;
  bool _recovering = false;
  int _recoveryGeneration = 0;
  late DateTime _listeningSince;

  void _startRecovery() {
    _recoveryTimer?.cancel();
    _recoveryGeneration++;
    _listeningSince = DateTime.now().toUtc();
    _recoveryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_recoverRoomEvents());
    });
    unawaited(_recoverRoomEvents());
  }

  Future<void> _recoverRoomEvents() async {
    if (!mounted || !_foreground || _recovering) return;
    _recovering = true;
    final generation = _recoveryGeneration;
    final room = widget.roomId;
    try {
      final rows = await ref
          .read(giftRepositoryProvider)
          .recentVerifiedRoomAnimations(
            room,
            since: _listeningSince.subtract(const Duration(seconds: 2)),
          );
      if (!mounted ||
          !_foreground ||
          widget.roomId != room ||
          generation != _recoveryGeneration)
        return;
      _receive(rows);
    } catch (_) {
      // RLS/network failures retry without re-sending or charging for gifts.
    } finally {
      _recovering = false;
    }
  }

  void _cancelMediaLookup() {
    _mediaTimer?.cancel();
    final wait = _mediaWait;
    if (wait != null && !wait.isCompleted) wait.complete(null);
    _mediaWait = null;
  }

  Future<String?> _lookupMedia(String giftId) {
    _cancelMediaLookup();
    final wait = Completer<String?>();
    _mediaWait = wait;
    _mediaTimer = Timer(const Duration(seconds: 8), () {
      if (!wait.isCompleted) wait.complete(null);
    });

    // A remote lookup failure must not suppress a bundled original. Complete
    // with null rather than leaving an unhandled asynchronous error.
    Future<void> resolve() async {
      String? remote;
      try {
        remote = await ref
            .read(giftRepositoryProvider)
            .approvedAnimationUrl(giftId);
      } catch (_) {
        // Offline clients can still play a verified bundled original.
      }
      if (wait.isCompleted) return;
      if (!wait.isCompleted) wait.complete(remote);
    }

    // Start immediately: do not defer the server media lookup into a later
    // event-loop turn; that delays verified effects and races widget teardown.
    unawaited(
      resolve().catchError((Object _) {
        if (!wait.isCompleted) wait.complete(null);
      }),
    );
    return wait.future;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRecovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _listeningSince = DateTime.now().toUtc();
    }
    if (!_foreground) {
      _timer?.cancel();
      _cancelMediaLookup();
      _pending.clear();
      if (mounted) {
        setState(() {
          _active = null;
          _participants = const {};
          _video = null;
          _loading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant VerifiedGiftBroadcast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.countryCode != widget.countryCode) {
      _timer?.cancel();
      _cancelMediaLookup();
      _seen.clear();
      _pending.clear();
      _active = null;
      _participants = const {};
      _video = null;
      _loading = false;
      _startRecovery();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelMediaLookup();
    _recoveryTimer?.cancel();
    _recoveryGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _receive(List<Map<String, dynamic>> rows) {
    // Ignore history from before joining this room, but do not discard
    // a real gift that settles during initial Realtime subscription.
    final fresh =
        rows.where((r) {
          final date = DateTime.tryParse('${r['created_at'] ?? ''}');
          if (date == null || date.toUtc().isBefore(_listeningSince)) {
            return false;
          }
          return r['gift_id'] is String &&
              r['id'] != null &&
              _seen.add('${r['id']}');
        }).toList()..sort(
          (a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'),
        );
    // The server stream retains 100 events. Bound deduplication memory too.
    if (_seen.length > 200) {
      _seen.retainAll(rows.map((r) => '${r['id']}'));
    }
    if (!_foreground || fresh.isEmpty) return;
    _pending.addAll(fresh);
    // Keep the queue bounded during long-running room sessions.
    if (_pending.length > 100) {
      _pending.removeRange(0, _pending.length - 100);
    }
    if (_active == null) _next();
  }

  Future<void> _next() async {
    _timer?.cancel();
    if (!mounted || !_foreground) return;
    if (_pending.isEmpty) {
      setState(() {
        _active = null;
        _participants = const {};
        _video = null;
        _loading = false;
      });
      return;
    }
    final event = _pending.removeAt(0);
    setState(() {
      _active = event;
      _participants = const {};
      _video = null;
      _loading = true;
    });
    try {
      // Resolve both real user identities against RLS-protected profiles.
      // Run in parallel with media discovery and bound the wait time.
      final namesFuture = ref
          .read(giftRepositoryProvider)
          .participantNamesForVerifiedEvent(event)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => <String, String>{},
          );
      final giftId = '${event['gift_id']}';
      // Media is enabled only after its URL is approved in Supabase.
      // Do not reference unbundled assets: that breaks playback on devices.
      final url = freeGiftAnimationForId(giftId) == null
          ? await _lookupMedia(giftId)
          : null;
      final participants = await namesFuture;
      if (!mounted || !identical(_active, event)) return;
      _cancelMediaLookup();
      setState(() {
        _video = url;
        _participants = participants;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || !identical(_active, event)) return;
      _cancelMediaLookup();
      setState(() => _loading = false);
    }
    // Each real player or plain artwork receipt owns its completion callback.
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(
      verifiedGiftAnimationProvider((
        roomId: widget.roomId,
        countryCode: widget.countryCode,
      )),
    );
    // Reconcile the current AsyncData snapshot after each stream update.
    // The seen-ID set makes repeat rebuilds harmless, even when provider
    // delivery and Flutter frame scheduling are coalesced.
    if (events.hasValue) {
      final snapshot = events.value!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _receive(snapshot);
      });
    }
    final event = _active;
    if (event == null) return const SizedBox.shrink();
    final sender = _participants[event['sender_id']?.toString()] ?? 'A member';
    final recipient =
        _participants[event['receiver_id']?.toString()] ?? 'a member';
    final price = (event['unit_price'] as num?)?.toInt() ?? 0;
    final quantity = (event['quantity'] as num?)?.toInt() ?? 1;
    // Verified server event contains the gift UUID, not an arbitrary
    // client-provided label. Resolve other gift names from the live catalog.
    String catalogName = '${event['gift_name'] ?? 'Gift'}';
    String? catalogArtwork;
    final catalog = ref.watch(giftCatalogProvider).valueOrNull;
    if (catalog != null) {
      for (final gift in catalog) {
        if (gift.id == '${event['gift_id']}') {
          catalogName = gift.name;
          catalogArtwork = gift.assetPath;
          break;
        }
      }
    }
    final giftName = catalogName;
    if (_video != null &&
        ('${event['gift_id']}' == hallOfFameGiftId ||
            zodiacVapGiftIds.contains('${event['gift_id']}') ||
            privateAnimalVapGiftIds.contains('${event['gift_id']}'))) {
      return HallOfFameVapOverlay(
        key: ValueKey(event['id']),
        source: _video!,
        sender: sender,
        recipient: recipient,
        giftName: giftName,
        quantity: quantity,
        onFinished: () {
          if (mounted && identical(_active, event)) _next();
        },
      );
    }
    // For VAP-only gifts, do not fabricate a static celebration if the
    // approved transparent animation is offline or not approved.
    final eventGiftId = '${event['gift_id']}';
    if (!_loading &&
        _video == null &&
        (eventGiftId == hallOfFameGiftId ||
            zodiacVapGiftIds.contains(eventGiftId) ||
            privateAnimalVapGiftIds.contains(eventGiftId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_active, event)) _next();
      });
      return const SizedBox.shrink();
    }
    if (_video != null) {
      return GiftVideoOverlay(
        key: ValueKey(event['id']),
        source: _video!,
        sender: sender,
        recipient: recipient,
        giftName: '$giftName × $quantity',
        // Voice remains audible; users can enable the original video's sound.
        muted: true,
        onFinished: () {
          if (mounted && identical(_active, event)) _next();
        },
      );
    }
    final originalSvga = freeGiftAnimationForId('${event['gift_id']}');
    if (!_loading && originalSvga != null) {
      return FreeGiftSvgaOverlay(
        key: ValueKey(event['id']),
        source: originalSvga,
        giftName: giftName,
        sender: sender,
        recipient: recipient,
        quantity: quantity,
        onFinished: () {
          if (mounted && identical(_active, event)) _next();
        },
      );
    }
    if (!_loading) {
      return GiftArtworkReceipt(
        key: ValueKey(event['id']),
        giftName: giftName,
        sender: sender,
        recipient: recipient,
        quantity: quantity,
        assetPath: catalogArtwork,
        onFinished: () {
          if (mounted && identical(_active, event)) _next();
        },
      );
    }
    final colors = price >= 10000000
        ? [const Color(0xff710c19), const Color(0xffd6a347)]
        : price >= 5000000
        ? [const Color(0xff4e277e), const Color(0xffd6a347)]
        : [const Color(0xff8c6016), const Color(0xffe6bc58)];
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 70, 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffffe3a0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (giftName != 'Dragon' &&
                        giftName != 'Golden Dragon') ...[
                      const NimzoGiftControlArt(
                        'video_send_gift.webp',
                        width: 48,
                        height: 48,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        _loading
                            ? 'Preparing verified gift…'
                            : '${event['scope'] == 'country' ? 'COUNTRY GIFT' : 'ROOM GIFT'}  •  $giftName × $quantity  •  ${price * quantity} coins',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
