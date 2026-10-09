import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gift_repository.dart';
import 'gift_video_overlay.dart';

/// Server-settled gift announcements. Initial history is never replayed.
class VerifiedGiftBroadcast extends ConsumerStatefulWidget {
  const VerifiedGiftBroadcast(
      {super.key, required this.roomId, required this.countryCode});
  final String roomId, countryCode;
  @override
  ConsumerState<VerifiedGiftBroadcast> createState() => _BroadcastState();
}

class _BroadcastState extends ConsumerState<VerifiedGiftBroadcast> {
  final Set<String> _seen = {};
  final List<Map<String, dynamic>> _pending = [];
  bool _primed = false;
  Map<String, dynamic>? _active;
  Timer? _timer;
  String? _video;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant VerifiedGiftBroadcast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.countryCode != widget.countryCode) {
      _timer?.cancel();
      _seen.clear();
      _pending.clear();
      _primed = false;
      _active = null;
      _video = null;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _receive(List<Map<String, dynamic>> rows) {
    if (!_primed) {
      _seen.addAll(rows.map((r) => '${r['id']}'));
      _primed = true;
      return;
    }
    final fresh = rows.where((r) => _seen.add('${r['id']}')).toList()
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    _pending.addAll(fresh);
    // Keep the queue bounded during long-running room sessions.
    if (_pending.length > 100) {
      _pending.removeRange(0, _pending.length - 100);
    }
    if (_active == null) _next();
  }

  Future<void> _next() async {
    _timer?.cancel();
    if (!mounted) return;
    if (_pending.isEmpty) {
      setState(() {
        _active = null;
        _video = null;
        _loading = false;
      });
      return;
    }
    final event = _pending.removeAt(0);
    setState(() {
      _active = event;
      _video = null;
      _loading = true;
    });
    try {
      final db = ref.read(giftRepositoryProvider);
      final giftId = '${event['gift_id']}';
      // Media is enabled only after its URL is approved in Supabase.
      // Do not reference unbundled assets: that breaks playback on devices.
      final url = await db.approvedAnimationUrl(giftId);
      if (!mounted || !identical(_active, event)) return;
      setState(() {
        _video = url;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || !identical(_active, event)) return;
      setState(() => _loading = false);
    }
    if (_video == null) {
      final price = (event['unit_price'] as num?)?.toInt() ?? 0;
      _timer = Timer(
          Duration(
              seconds: price >= 10000000
                  ? 5
                  : price >= 5000000
                      ? 4
                      : 3),
          _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(verifiedGiftAnimationProvider(
        (roomId: widget.roomId, countryCode: widget.countryCode)));
    ref.listen(
        verifiedGiftAnimationProvider(
            (roomId: widget.roomId, countryCode: widget.countryCode)),
        (_, next) {
      if (next.hasValue) _receive(next.value!);
    });
    if (!_primed && events.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_primed) _receive(events.value!);
      });
    }
    final event = _active;
    if (event == null) return const SizedBox.shrink();
    final price = (event['unit_price'] as num?)?.toInt() ?? 0;
    if (_video != null) {
      return GiftVideoOverlay(
        key: ValueKey(event['id']),
        source: _video!,
        sender: (event['sender_name'] ?? event['sender_id'] ?? '').toString(),
        recipient:
            (event['receiver_name'] ?? event['receiver_id'] ?? '').toString(),
        giftName:
            '${event['gift_id']}' == 'c3f41e6e-68d5-4e56-9253-33421ec18fc3'
                ? 'Golden Dragon'
                : '${event['gift_name'] ?? 'Gift'}',
        onFinished: _next,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(
                  _loading
                      ? 'Preparing verified gift…'
                      : '${event['scope'] == 'country' ? 'COUNTRY GIFT' : 'ROOM GIFT'}  •  ${price.toString()} coins',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
