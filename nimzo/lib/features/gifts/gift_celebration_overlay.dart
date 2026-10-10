import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'gift_artwork.dart';
import 'nimzo_gift_control_art.dart';
import 'gift_svga_overlay.dart';
import '../../core/utils/formatters.dart';

/// NIMZO's own non-video celebration, shown only for server-settled gifts.
/// Does not pretend to be an unavailable foreign per-gift animation.
class NimzoGiftCelebration extends StatefulWidget {
  const NimzoGiftCelebration({
    super.key,
    required this.giftName,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.unitPrice,
    required this.onFinished,
    this.assetPath,
    this.scope = 'room',
  });
  final String giftName, sender, recipient, scope;
  final int quantity, unitPrice;
  final String? assetPath;
  final VoidCallback onFinished;

  @override
  State<NimzoGiftCelebration> createState() => _NimzoGiftCelebrationState();
}

class _NimzoGiftCelebrationState extends State<NimzoGiftCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final milliseconds = widget.unitPrice >= 5000000
        ? 4700
        : widget.unitPrice >= 1000000
            ? 3700
            : widget.unitPrice >= 10000
                ? 2600
                : 1700;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: milliseconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_finished) {
          _finished = true;
          widget.onFinished();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = widget.unitPrice >= 1000000;
    final accent = widget.unitPrice >= 5000000
        ? const Color(0xfff6c868)
        : premium
            ? const Color(0xffd79bfa)
            : widget.unitPrice >= 10000
                ? const Color(0xff79d5e9)
                : const Color(0xffb0edb9);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final fade = t < .14
                  ? t / .14
                  : t > .87
                      ? (1 - t) / .13
                      : 1.0;
              final scale = .72 + .28 * Curves.easeOutCubic.transform(t);
              return Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: const Color(0xff050e10)
                            .withValues(alpha: premium ? .65 : .42),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GiftSparkles(t, accent, premium ? 36 : 24),
                      ),
                    ),
                    Center(
                      child: Transform.scale(
                        scale: scale,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: narrow ? 16 : 25,
                            ),
                            padding: const EdgeInsets.fromLTRB(17, 22, 17, 18),
                            decoration: BoxDecoration(
                              color: const Color(0xff132121),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: accent, width: 1.6),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: .29),
                                  blurRadius: 38,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.scope == 'country'
                                      ? 'NIMZO COUNTRY GIFT'
                                      : 'NIMZO GIFT',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 176,
                                  height: 163,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.rotate(
                                        angle: t * math.pi * 1.2,
                                        child: Container(
                                          width: 146,
                                          height: 146,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: accent.withValues(alpha: .5),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 136,
                                        height: 136,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(colors: [
                                            accent.withValues(alpha: .3),
                                            accent.withValues(alpha: .02),
                                          ]),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        height: 130,
                                        child: GiftArtwork(
                                          name: widget.giftName,
                                          assetPath: widget.assetPath,
                                        ),
                                      ),
                                      const Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: NimzoGiftControlArt(
                                          'video_send_gift.webp',
                                          width: 43,
                                          height: 43,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  widget.giftName,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: narrow ? 21 : 27,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '× ${widget.quantity}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${compactNumber(widget.unitPrice * widget.quantity)} coins',
                                  style: const TextStyle(
                                    color: Color(0xffd5dfe1),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  '${widget.sender}  →  ${widget.recipient}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GiftSparkles extends CustomPainter {
  const _GiftSparkles(this.progress, this.color, this.count);
  final double progress;
  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final spread = math.min(size.width, size.height) * .52;
    for (var i = 0; i < count; i++) {
      final theta = (i * 2.3999632) + progress * (i.isEven ? 1.4 : -.8);
      final age = (progress * 1.7 + i / count) % 1;
      final radius = 30 + age * spread;
      final point = Offset(
        origin.dx + math.cos(theta) * radius,
        origin.dy + math.sin(theta) * radius,
      );
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - age) * .9)
        ..strokeWidth = i.isEven ? 2.0 : 1.1
        ..strokeCap = StrokeCap.round;
      final length = 2.0 + (1 - age) * (i.isEven ? 6 : 4);
      canvas.drawLine(
        point.translate(-length, 0),
        point.translate(length, 0),
        paint,
      );
      canvas.drawLine(
        point.translate(0, -length),
        point.translate(0, length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GiftSparkles old) =>
      old.progress != progress || old.color != color || old.count != count;
}

/// Personal/Moment gifts have no room broadcast. Display only after the
/// settlement RPC returns success. Removes itself after playback completes.
void showSettledPersonalGiftCelebration(
  BuildContext context, {
  required String giftName,
  required int quantity,
  required int unitPrice,
  String? assetPath,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  var removed = false;
  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
  }

  final originalSvga = freeGiftAnimationForName(giftName);
  entry = OverlayEntry(
    builder: (_) => originalSvga != null
        ? FreeGiftSvgaOverlay(
            source: originalSvga,
            giftName: giftName,
            sender: 'You',
            recipient: 'NIMZO user',
            quantity: quantity,
            onFinished: dismiss,
          )
        : NimzoGiftCelebration(
      giftName: giftName,
      sender: 'You',
      recipient: 'NIMZO user',
      quantity: quantity,
      unitPrice: unitPrice,
      assetPath: assetPath,
      onFinished: dismiss,
    ),
  );
  overlay.insert(entry);
}
